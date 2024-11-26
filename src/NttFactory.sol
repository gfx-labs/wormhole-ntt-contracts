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
        string externalSalt;
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
    event TransceiverDeployed(address indexed transceiver, address indexed token);
    event PeerSet(address indexed manager, uint16 chainId, bytes32 peer);

    // --- Errors ---
    error DeploymentFailed();
    error InvalidParameters();

    // --- State ---
    bytes32 public immutable VERSION;

    constructor(bytes32 _version) {
        if (_version == bytes32(0)) revert InvalidParameters();
        VERSION = _version;
    }

    /**
     * @notice Deploy a new NTT token, its manager and transceiver deterministically
     * @param mode Mode of the manager
     * @param newTokenName Name of the new token
     * @param newTokenSymbol Symbol of the new token
     * @param tokenAddress Address of the token
     * @param externalSalt External salt used for deterministic deployment
     * @param newTokenInitialSupply Initial supply of the new token
     * @param outboundLimit Outbound limit for the new token
     * @param envParams Environment parameters for the deployment
     * @param peerParams Peer parameters for the deployment
     * @param nttManagerBytecode Bytecode of the NTT manager
     * @param nttTransceiverBytecode Bytecode of the NTT transceiver
     * @return token Address of the deployed token
     * @return nttManager Address of the deployed manager
     * @return transceiver Address of the deployed transceiver
     */
    function deployNtt(
        IManagerBase.Mode mode,
        string memory newTokenName,
        string memory newTokenSymbol,
        address tokenAddress,
        string memory externalSalt,
        uint256 newTokenInitialSupply,
        uint256 outboundLimit,
        EnvParams memory envParams,
        PeerParams[] memory peerParams,
        bytes memory nttManagerBytecode,
        bytes memory nttTransceiverBytecode
    ) external returns (address token, address nttManager, address transceiver) {
        if (bytes(newTokenName).length == 0 || bytes(newTokenSymbol).length == 0) revert InvalidParameters();

        address owner = msg.sender;

        token =
            (mode == IManagerBase.Mode.BURNING) ? deployToken(newTokenName, newTokenSymbol, externalSalt) : tokenAddress;

        // deploy manager
        uint16 chainId = IWormhole(envParams.wormholeCoreBridge).chainId();
        DeploymentParams memory params = DeploymentParams({
            token: token,
            mode: mode,
            wormholeChainId: chainId,
            rateLimitDuration: 86400,
            shouldSkipRatelimiter: false,
            wormholeCoreBridge: envParams.wormholeCoreBridge,
            wormholeRelayerAddr: envParams.wormholeRelayerAddr,
            specialRelayerAddr: envParams.specialRelayerAddr,
            consistencyLevel: 202,
            gasLimit: 500000,
            outboundLimit: outboundLimit,
            externalSalt: externalSalt
        });
        nttManager = deployNttManager(params, nttManagerBytecode);

        if (params.mode == IManagerBase.Mode.BURNING) {
            configureTokenSettings(token, owner, newTokenInitialSupply, nttManager);
        }

        // Configure NttManager, but not ownership
        // To be able to call `configureNttTransceiver` from this factory
        configureNttManager(nttManager, peerParams, params.outboundLimit, params.shouldSkipRatelimiter);

        // Deploy Wormhole Transceiver.
        transceiver = deployWormholeTransceiver(params, nttManager, nttTransceiverBytecode);

        // with the transceiver deployed, we are able to set it
        IManagerBase(nttManager).setTransceiver(transceiver);

        // As is only one transceiver now, with set to 1
        INttManager(nttManager).setThreshold(1);

        // Now transceiver can be configured from this factory
        configureNttTransceiver(transceiver, peerParams);

        // change ownership of nttManager to tokenOwner now that everything is configured
        PausableOwnable(nttManager).transferPauserCapability(owner);
        PausableOwnable(nttManager).transferOwnership(owner);

        emit ManagerDeployed(nttManager, token);
        emit TransceiverDeployed(transceiver, token);

        return (token, nttManager, transceiver);
    }

    function deployToken(string memory _name, string memory _symbol, string memory _externalSalt)
        internal
        returns (address)
    {
        bytes32 tokenSalt = keccak256(abi.encodePacked(VERSION, msg.sender, _name, _symbol, _externalSalt));

        // Deploy token. Initially we need to have minter and owner as this factory.
        address token = CREATE3.deploy(
            tokenSalt,
            abi.encodePacked(type(PeerToken).creationCode, abi.encode(_name, _symbol, address(this), address(this))),
            0
        );

        emit TokenDeployed(token, _name, _symbol);

        return token;
    }

    function configureTokenSettings(address token, address owner, uint256 _initialSupply, address nttManager)
        internal
    {
        // caller nttFactory
        PeerToken(token).mint(owner, _initialSupply);

        // move minter from factory to nttManager
        PeerToken(token).setMinter(nttManager);

        // but leave ownership to tokenOwner
        Ownable(token).transferOwnership(owner);
    }

    function deployNttManager(DeploymentParams memory params, bytes memory nttManagerBytecode)
        internal
        returns (address)
    {
        // We don't want to get the same bytecode if the token is the same, using externalSalt here too
        bytes32 implementationSalt =
            keccak256(abi.encodePacked(VERSION, "MANAGER_IMPL", msg.sender, params.externalSalt, address(this)));

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

        // Get the same address across chains for the proxy. We can't use token address for hub and spoke
        bytes32 managerSalt = keccak256(abi.encodePacked(VERSION, "MANAGER", msg.sender, params.externalSalt));

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

        // Get the same address across chains for the proxy
        bytes32 transceiverSalt = keccak256(abi.encodePacked(VERSION, "TRANSCEIVER", msg.sender, nttManager));

        // Deploy deterministic nttTransceiverProxy
        bytes memory proxyCreationCode =
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implementation, ""));

        WormholeTransceiver transceiverProxy =
            WormholeTransceiver(CREATE3.deploy(transceiverSalt, proxyCreationCode, 0));

        transceiverProxy.initialize();

        return address(transceiverProxy);
    }

    function configureNttTransceiver(address transceiver, PeerParams[] memory peerParams) internal {
        bytes32 normalizedTransceiverAddress = bytes32(uint256(uint160(transceiver)));

        for (uint256 i = 0; i < peerParams.length; i++) {
            WormholeTransceiver(transceiver).setWormholePeer(peerParams[i].peerChainId, normalizedTransceiverAddress);
            WormholeTransceiver(transceiver).setIsWormholeEvmChain(peerParams[i].peerChainId, true);
            WormholeTransceiver(transceiver).setIsWormholeRelayingEnabled(peerParams[i].peerChainId, true);
        }
    }

    function configureNttManager(
        address nttManager,
        PeerParams[] memory peerParams,
        uint256 outboundLimit,
        bool shouldSkipRateLimiter
    ) internal {
        if (!shouldSkipRateLimiter) {
            INttManager(nttManager).setOutboundLimit(outboundLimit);
        }

        bytes32 normalizedAddress = bytes32(uint256(uint160(nttManager)));
        for (uint256 i = 0; i < peerParams.length; i++) {
            INttManager(nttManager).setPeer(
                peerParams[i].peerChainId, normalizedAddress, peerParams[i].decimals, peerParams[i].inboundLimit
            );
        }
    }
}
