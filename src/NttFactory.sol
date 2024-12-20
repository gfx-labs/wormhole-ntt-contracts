// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {CREATE3} from "solmate/utils/CREATE3.sol";

import {Implementation} from "native-token-transfers/libraries/Implementation.sol";
import {PausableOwnable} from "native-token-transfers/libraries/PausableOwnable.sol";
import {IManagerBase} from "native-token-transfers/interfaces/IManagerBase.sol";
import {INttManager} from "native-token-transfers/interfaces/INttManager.sol";
import {IWormhole} from "wormhole-solidity-sdk/interfaces/IWormhole.sol";
import {IWormholeTransceiver} from "native-token-transfers/interfaces/IWormholeTransceiver.sol";
import {INttFactory} from "./interfaces/INttFactory.sol";
import {NttOwner} from "./NttOwner.sol";

import {PeersLibrary} from "./PeersLibrary.sol";

import {PeerToken} from "vendor/tokens/PeerToken.sol";

/**
 * @title NttFactory
 * @notice Factory contract for deploying cross-chain NTT tokens with their managers, transceivers and owner contract
 */
contract NttFactory is INttFactory {
    // --- State ---

    /// @notice Contract version for upgrade tracking
    /// @dev Should be incremented on each upgrade
    bytes32 public constant VERSION = "0.0.70";

    /// @notice Default values used for manager and transceiver deploy
    /// @dev Same default values as used on the cli
    bool public constant SHOULD_SKIP_RATE_LIMITER = false;
    uint64 public constant RATE_LIMIT_DURATION = 24 hours;
    uint256 public constant GAS_LIMIT = 500000;
    uint8 public constant CONSISTENCY_LEVEL = 202;

    uint16 public wormholeChainId;
    address public wormholeCoreBridge;
    address public wormholeRelayer;
    address public specialRelayer;

    /// @notice Deployer address to restrict the call to initializeBytecode
    address public immutable deployer;

    bytes public nttManagerBytecode;
    bytes public nttTransceiverBytecode;

    modifier onlyDeployer() {
        if (msg.sender != deployer) {
            revert NotDeployer();
        }
        _;
    }

    constructor(address deployerAddress) {
        deployer = deployerAddress;
    }

    function initializeWormholeConfig(
        address whCoreBridge,
        address whRelayer,
        address whSpecialRelayer,
        uint16 whChainId
    ) external onlyDeployer {
        if (
            wormholeCoreBridge != address(0) || wormholeCoreBridge != address(0) || specialRelayer != address(0)
                || wormholeChainId != 0
        ) {
            revert WormholeConfigAlreadyInitialized();
        }

        wormholeCoreBridge = whCoreBridge;
        wormholeRelayer = whRelayer;
        specialRelayer = whSpecialRelayer;
        wormholeChainId = whChainId;

        emit WormholeConfigInitialized(wormholeCoreBridge, wormholeRelayer, specialRelayer, wormholeChainId);
    }

    /**
     * @notice Initialize transceiver bytecode to be used on deploy of NTT transceiver
     * @param transceiverBytecode creationCode for the transceiver
     */
    function initializeTransceiverBytecode(bytes calldata transceiverBytecode) external onlyDeployer {
        if (transceiverBytecode.length == 0) {
            revert InvalidBytecodes();
        }
        if (nttTransceiverBytecode.length != 0) {
            revert TransceiverBytecodeAlreadyInitialized();
        }

        nttTransceiverBytecode = transceiverBytecode;

        emit TransceiverBytecodeInitialized(keccak256(transceiverBytecode));
    }

    /**
     * @notice Initialize manager bytecode to be used on deploy of NTT manager
     * @param managerBytecode creationCode for the manager
     */
    function initializeManagerBytecode(bytes calldata managerBytecode) external onlyDeployer {
        if (managerBytecode.length == 0) {
            revert InvalidBytecodes();
        }
        if (nttManagerBytecode.length != 0) {
            revert ManagerBytecodeAlreadyInitialized();
        }

        nttManagerBytecode = managerBytecode;

        emit ManagerBytecodeInitialized(keccak256(managerBytecode));
    }

    /// @inheritdoc INttFactory
    function deployNtt(
        IManagerBase.Mode mode,
        TokenParams memory tokenParams,
        string memory externalSalt,
        uint256 outboundLimit,
        PeersLibrary.PeerParams[] memory peerParams
    ) external returns (address token, address nttManager, address transceiver, address nttOwnerAddress) {
        if (bytes(tokenParams.name).length == 0 || bytes(tokenParams.symbol).length == 0) {
            revert InvalidTokenParameters();
        }

        if (nttManagerBytecode.length == 0 || nttTransceiverBytecode.length == 0) {
            revert BytecodesNotInitialized();
        }
        address owner = msg.sender;

        NttOwner ownerContract = new NttOwner(owner);

        token = (mode == IManagerBase.Mode.BURNING)
            ? deployToken(tokenParams.name, tokenParams.symbol, externalSalt)
            : tokenParams.existingAddress;

        // deploy manager
        DeploymentParams memory params =
            DeploymentParams({token: token, mode: mode, outboundLimit: outboundLimit, externalSalt: externalSalt});
        nttManager = deployNttManager(params);

        if (params.mode == IManagerBase.Mode.BURNING) {
            configureTokenSettings(token, owner, tokenParams.initialSupply, nttManager);
        }

        // Don't skip rate limiting
        INttManager(nttManager).setOutboundLimit(params.outboundLimit);

        // Configure NttManager, but not ownership
        // To be able to call `configureNttTransceiver` from this factory
        PeersLibrary.configureNttManager(INttManager(nttManager), peerParams);

        // Deploy Wormhole Transceiver.
        transceiver = deployWormholeTransceiver(nttManager);

        // with the transceiver deployed, we are able to set it
        IManagerBase(nttManager).setTransceiver(transceiver);

        // Now transceiver can be configured from this factory
        PeersLibrary.configureNttTransceiver(IWormholeTransceiver(transceiver), peerParams);

        // change ownership and pauser capability of nttManager and transceiver
        // to owner contract now that everything is configured
        PausableOwnable(nttManager).transferOwnership(address(ownerContract));
        PausableOwnable(nttManager).transferPauserCapability(address(ownerContract));
        PausableOwnable(transceiver).transferPauserCapability(address(ownerContract));

        emit ManagerDeployed(nttManager, token);
        emit TransceiverDeployed(transceiver, token);
        emit NttOwnerDeployed(address(ownerContract), nttManager, transceiver);

        return (token, nttManager, transceiver, address(ownerContract));
    }

    function deployToken(string memory name, string memory symbol, string memory externalSalt)
        internal
        returns (address)
    {
        bytes32 tokenSalt = keccak256(abi.encodePacked(VERSION, msg.sender, name, symbol, externalSalt));

        // Deploy token. Initially we need to have minter and owner as this factory.
        address token = CREATE3.deploy(
            tokenSalt,
            abi.encodePacked(type(PeerToken).creationCode, abi.encode(name, symbol, address(this), address(this))),
            0
        );

        emit TokenDeployed(token, name, symbol);

        return token;
    }

    function configureTokenSettings(address token, address owner, uint256 initialSupply, address nttManager) internal {
        if (initialSupply > 0) {
            PeerToken(token).mint(owner, initialSupply);
        }

        // move minter from factory to nttManager
        PeerToken(token).setMinter(nttManager);

        // but leave ownership to tokenOwner
        Ownable(token).transferOwnership(owner);
    }

    function deployAndInitializeProxy(address implementation, bytes32 salt) internal returns (address) {
        // Deploy deterministic proxy
        bytes memory proxyCreationCode =
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implementation, ""));

        address proxy = CREATE3.deploy(salt, proxyCreationCode, 0);

        Implementation(proxy).initialize();

        return proxy;
    }

    function deployNttManager(DeploymentParams memory params) internal returns (address) {
        // We don't want to get the same bytecode if the token is the same, using externalSalt here too
        bytes32 implementationSalt =
            keccak256(abi.encodePacked(VERSION, "MANAGER_IMPL", msg.sender, params.externalSalt, address(this)));

        bytes memory bytecode = abi.encodePacked(
            nttManagerBytecode,
            abi.encode(params.token, params.mode, wormholeChainId, RATE_LIMIT_DURATION, SHOULD_SKIP_RATE_LIMITER)
        );

        address implementation = Create2.deploy(0, implementationSalt, bytecode);

        // Get the same address across chains for the proxy. We can't use token address for hub and spoke
        bytes32 managerSalt = keccak256(abi.encodePacked(VERSION, "MANAGER", msg.sender, params.externalSalt));

        return deployAndInitializeProxy(implementation, managerSalt);
    }

    function deployWormholeTransceiver(address nttManager) internal returns (address) {
        bytes32 implementationSalt = keccak256(abi.encodePacked(VERSION, "TRANSCEIVER_SALT", msg.sender, address(this)));

        bytes memory bytecode = abi.encodePacked(
            nttTransceiverBytecode,
            abi.encode(nttManager, wormholeCoreBridge, wormholeRelayer, specialRelayer, CONSISTENCY_LEVEL, GAS_LIMIT)
        );
        address implementation = Create2.deploy(0, implementationSalt, bytecode);

        // Get the same address across chains for the proxy
        bytes32 transceiverSalt = keccak256(abi.encodePacked(VERSION, "TRANSCEIVER", msg.sender, nttManager));

        return deployAndInitializeProxy(implementation, transceiverSalt);
    }

    /**
     * @inheritdoc INttFactory
     */
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(INttFactory).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
