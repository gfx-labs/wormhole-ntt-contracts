// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PeerToken} from "vendor/tokens/PeerToken.sol";
import {CREATE3} from "solmate/utils/CREATE3.sol";
import {IManagerBase} from "vendor/interfaces/IManagerBase.sol";
import {NttManager} from "vendor/NttManager/NttManager.sol";
import {WormholeTransceiver} from "vendor/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";
import {INttManager} from "vendor/interfaces/INttManager.sol";

interface IWormhole {
    function chainId() external view returns (uint16);
}

/**
 * @title NttFactory
 * @notice Factory contract for deploying cross-chain NTT tokens and their managers
 */
contract NttFactory is Ownable {
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

    constructor(address _owner, bytes32 _version) Ownable(_owner) {
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
     * @return manager Address of deployed manager
     * @return tranceiver Address of deployed tranceiver
     */
    function deployNtt(
        string memory _name,
        string memory _symbol,
        address _minter,
        address _tokenOwner,
        EnvParams memory envParams,
        bytes memory nttManagerBytecode,
        bytes memory nttTransceiverBytecode
    ) external onlyOwner returns (address token, address manager, address tranceiver) {
        if (_minter == address(0) || _tokenOwner == address(0)) revert ZeroAddress();
        if (bytes(_name).length == 0 || bytes(_symbol).length == 0) revert InvalidParameters();

        bytes32 tokenSalt = keccak256(abi.encodePacked(VERSION, "TOKEN", _name, _symbol));

        // Deploy token
        token = CREATE3.deploy(
            tokenSalt,
            abi.encodePacked(type(PeerToken).creationCode, abi.encode(_name, _symbol, _minter, _tokenOwner)),
            0
        );
        if (token == address(0)) revert DeploymentFailed();

        // deploy manager
        IWormhole wh = IWormhole(envParams.wormholeCoreBridge); // FIXME double check
        uint16 chainId = wh.chainId();

        // TODO Separate params between manager and tranceiver
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
        address nttManager = deployNttManager(params, nttManagerBytecode);

        // Deploy Wormhole Transceiver.
        address transceiver = deployWormholeTransceiver(params, nttManager, nttTransceiverBytecode);

        // Configure NttManager.
        // setPeer
        // TODO Add peers as parameters
        configureNttManager(nttManager, transceiver, params.outboundLimit, params.shouldSkipRatelimiter);

        emit TokenDeployed(token, _name, _symbol);
        emit ManagerDeployed(nttManager, token);
        emit TranceiverDeployed(tranceiver, token);

        return (token, manager, transceiver);
    }

    function deployNttManager(DeploymentParams memory params, bytes memory nttManagerBytecode)
        internal
        returns (address)
    {
        NttManager implementation = NttManager(
            CREATE3.deploy(
                "test",
                abi.encodePacked(
                    nttManagerBytecode,
                    abi.encode(
                        params.token,
                        params.mode,
                        params.wormholeChainId,
                        params.rateLimitDuration,
                        params.shouldSkipRatelimiter
                    )
                ),
                0
            )
        );

        // Get the same address across chains
        bytes32 managerSalt = keccak256(abi.encodePacked(VERSION, "MANAGER", params.token));

        // Deploy deterministic nttManagerProxy
        NttManager nttManagerProxy = NttManager(
            CREATE3.deploy(
                managerSalt, abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(implementation))), 0
            )
        );
        if (address(nttManagerProxy) == address(0)) revert DeploymentFailed();

        nttManagerProxy.initialize();

        return address(nttManagerProxy);
    }

    function deployWormholeTransceiver(
        DeploymentParams memory params,
        address nttManager,
        bytes memory nttTransceiverBytecode
    ) internal returns (address) {
        WormholeTransceiver implementation = WormholeTransceiver(
            CREATE3.deploy(
                "test",
                abi.encodePacked(
                    nttTransceiverBytecode,
                    abi.encode(
                        nttManager,
                        params.wormholeCoreBridge,
                        params.wormholeRelayerAddr,
                        params.specialRelayerAddr,
                        params.consistencyLevel,
                        params.gasLimit
                    )
                ),
                0
            )
        );

        WormholeTransceiver transceiverProxy =
            WormholeTransceiver(address(new ERC1967Proxy(address(implementation), "")));

        transceiverProxy.initialize();

        return address(transceiverProxy);
    }

    function configureNttManager(
        address nttManager,
        address transceiver,
        uint256 outboundLimit,
        bool shouldSkipRateLimiter
    ) public {
        IManagerBase(nttManager).setTransceiver(transceiver);

        if (!shouldSkipRateLimiter) {
            INttManager(nttManager).setOutboundLimit(outboundLimit);
        }

        // Hardcoded to one since these scripts handle Wormhole-only deployments.
        INttManager(nttManager).setThreshold(1);
    }

    // TODO upgrade implementation
}
