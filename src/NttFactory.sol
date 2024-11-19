// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Create2} from "lib/openzeppelin-contracts/contracts/utils/Create2.sol";
import {CREATE3} from "solmate/utils/CREATE3.sol";

import {NttManager} from "vendor/NttManager/NttManager.sol";
import {PeerToken} from "vendor/tokens/PeerToken.sol";
import {PausableOwnable} from "vendor/libraries/PausableOwnable.sol";
import {WormholeTransceiver} from "vendor/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";
import {IManagerBase} from "vendor/interfaces/IManagerBase.sol";
import {INttManager} from "vendor/interfaces/INttManager.sol";
import {ITransceiver} from "vendor/interfaces/ITransceiver.sol";

interface IWormhole {
    function chainId() external view returns (uint16);
}

/**
 * @title NttFactory
 * @notice Factory contract for deploying cross-chain NTT tokens and their managers
 */
contract NttFactory {
    // --- Structs ---
    struct EnvParams {
        address wormholeCoreBridge;
        address wormholeRelayerAddr;
        address specialRelayerAddr;
    }

    struct DeploymentParams {
        address token;
        IManagerBase.Mode mode;
        uint16 wormholeChainId;
        uint64 rateLimitDuration;
        bool shouldSkipRatelimiter;
        address wormholeCoreBridge;
        address wormholeRelayerAddr;
        address specialRelayerAddr;
        uint8 consistencyLevel;
        uint256 gasLimit;
        uint256 outboundLimit;
    }

    struct PeerParams {
        uint16 peerChainId;
        // bytes32 peerContract;
        uint8 decimals;
        uint256 inboundLimit;
    }

    // --- Events ---
    event TokenDeployed(address indexed token, string name, string symbol);
    event ManagerDeployed(address indexed manager, address indexed token);
    event TranceiverDeployed(address indexed tranceiver, address indexed token);
    event PeerSet(address indexed manager, uint16 chainId, bytes32 peer);

    // --- Errors ---
    error ZeroAddress();
    error DeploymentFailed();
    error InvalidParameters();

    // --- State ---
    bytes32 public immutable VERSION;
    mapping(address => address) public tokenToManager;

    constructor(bytes32 _version) {
        if (_version == bytes32(0)) revert InvalidParameters();
        VERSION = _version;
    }

    /**
     * @notice Deploy a new NTT token and its manager
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _minter Initial minter address
     * @param _tokenOwner Token owner address
     * @return token Address of deployed token
     * @return nttManager Address of deployed manager
     * @return transceiver Address of deployed tranceiver
     */
    function deployNtt(
        string memory _name,
        string memory _symbol,
        address _minter, // Remove minter
        address _tokenOwner, // Copy from msg.sender
        uint256 _initialSupply,
        EnvParams memory envParams,
        PeerParams memory peerParams,
        bytes memory nttManagerBytecode,
        bytes memory nttTransceiverBytecode
    ) external returns (address token, address nttManager, address transceiver) {
        if (_minter == address(0) || _tokenOwner == address(0)) revert ZeroAddress();
        if (bytes(_name).length == 0 || bytes(_symbol).length == 0) revert InvalidParameters();

        bytes32 tokenSalt = keccak256(abi.encodePacked(VERSION, msg.sender, _name, _symbol));

        // Deploy token. Initially we need to have minter and owner as this factory.
        token = CREATE3.deploy(
            tokenSalt,
            abi.encodePacked(type(PeerToken).creationCode, abi.encode(_name, _symbol, address(this), address(this))),
            0
        );

        // deploy manager
        IWormhole wh = IWormhole(envParams.wormholeCoreBridge);
        uint16 chainId = wh.chainId();

        DeploymentParams memory params = DeploymentParams({
            token: token,
            mode: IManagerBase.Mode.BURNING, // FIXME change to support both
            wormholeChainId: chainId,
            rateLimitDuration: 86400,
            shouldSkipRatelimiter: false,
            wormholeCoreBridge: envParams.wormholeCoreBridge,
            wormholeRelayerAddr: envParams.wormholeRelayerAddr,
            specialRelayerAddr: envParams.specialRelayerAddr,
            consistencyLevel: 202,
            gasLimit: 500000,
            // the trimming will trim this number to uint64.max
            outboundLimit: uint256(type(uint64).max) * 1 // TODO apply scale for locking mode
        });
        nttManager = deployNttManager(params, nttManagerBytecode);

        // caller nttFactory
        PeerToken(token).mint(_tokenOwner, _initialSupply);

        // move minter from factory to nttManager
        PeerToken(token).setMinter(nttManager);

        // but leave ownership to tokenOwner
        Ownable(token).transferOwnership(_tokenOwner);

        // Deploy Wormhole Transceiver.
        transceiver = deployWormholeTransceiver(params, nttManager, nttTransceiverBytecode);

        // Configure NttManager. At the end the owner will be `owner` and not this factory
        configureNttManager(
            nttManager, transceiver, _tokenOwner, peerParams, params.outboundLimit, params.shouldSkipRatelimiter
        );

        emit TokenDeployed(token, _name, _symbol);
        emit ManagerDeployed(nttManager, token);
        emit TranceiverDeployed(transceiver, token);

        return (token, nttManager, transceiver);
    }

    function deployNttManager(DeploymentParams memory params, bytes memory nttManagerBytecode)
        internal
        returns (address)
    {
        bytes32 implementationSalt = keccak256(abi.encodePacked(VERSION, "MANAGER_IMPL", msg.sender, address(this)));

        bytes memory bytecode = abi.encodePacked(
            nttManagerBytecode,
            abi.encode(
                params.token,
                params.mode,
                params.wormholeChainId,
                params.rateLimitDuration,
                params.shouldSkipRatelimiter
            )
        );

        address implementation = Create2.deploy(0, implementationSalt, bytecode);

        // Get the same address across chains for the proxy
        bytes32 managerSalt = keccak256(abi.encodePacked(VERSION, "MANAGER", msg.sender, params.token));

        // Deploy deterministic nttManagerProxy
        bytes memory proxyCreationCode =
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implementation, ""));

        NttManager nttManagerProxy = NttManager(CREATE3.deploy(managerSalt, proxyCreationCode, 0));

        // This is made here, not in constructor because only the deployer can call it
        nttManagerProxy.initialize();

        return address(nttManagerProxy);
    }

    function deployWormholeTransceiver(
        DeploymentParams memory params,
        address nttManager,
        bytes memory nttTransceiverBytecode
    ) internal returns (address) {
        bytes32 implementationSalt = keccak256(abi.encodePacked(VERSION, "TRANSCEIVER_SALT", msg.sender, address(this)));

        bytes memory bytecode = abi.encodePacked(
            nttTransceiverBytecode,
            abi.encode(
                nttManager,
                params.wormholeCoreBridge,
                params.wormholeRelayerAddr,
                params.specialRelayerAddr,
                params.consistencyLevel,
                params.gasLimit
            )
        );
        address implementation = Create2.deploy(0, implementationSalt, bytecode);

        WormholeTransceiver transceiverProxy = WormholeTransceiver(address(new ERC1967Proxy(implementation, "")));

        transceiverProxy.initialize();

        return address(transceiverProxy);
    }

    function configureNttManager(
        address nttManager,
        address transceiver,
        address owner,
        PeerParams memory peerParams,
        uint256 outboundLimit,
        bool shouldSkipRateLimiter
    ) public {
        IManagerBase(nttManager).setTransceiver(transceiver);

        if (!shouldSkipRateLimiter) {
            INttManager(nttManager).setOutboundLimit(outboundLimit);
        }

        bytes32 normalizedAddress = bytes32(uint256(uint160(nttManager)));

        INttManager(nttManager).setPeer(
            peerParams.peerChainId, normalizedAddress, peerParams.decimals, peerParams.inboundLimit
        );

        // Hardcoded to one since these scripts handle Wormhole-only deployments.
        INttManager(nttManager).setThreshold(1);

        PausableOwnable(nttManager).transferPauserCapability(owner);
        PausableOwnable(nttManager).transferOwnership(owner);
    }

    // TODO upgrade implementation
}
