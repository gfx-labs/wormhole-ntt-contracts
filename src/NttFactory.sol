// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {CREATE3} from "solady/utils/CREATE3.sol";
import {SSTORE2} from "solady/utils/SSTORE2.sol";
import {Implementation} from "native-token-transfers/libraries/Implementation.sol";
import {PausableOwnable} from "native-token-transfers/libraries/PausableOwnable.sol";
import {IManagerBase} from "native-token-transfers/interfaces/IManagerBase.sol";
import {INttManager} from "native-token-transfers/interfaces/INttManager.sol";
import {IWormholeTransceiver} from "native-token-transfers/interfaces/IWormholeTransceiver.sol";
import {INttFactory} from "./interfaces/INttFactory.sol";
import {NttProxyOwner} from "./NttProxyOwner.sol";
import {PeersManager} from "./PeersManager.sol";
import {PeerToken} from "./tokens/PeerToken.sol";

interface IWormhole {
    function messageFee() external view returns (uint256);
}

/**
 * @title NttFactory
 * @notice Factory contract for deploying cross-chain NTT tokens with their managers, transceivers and owner contract
 */
contract NttFactory is INttFactory, PeersManager {
    // --- State ---

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

    /// @notice Contract version for upgrade tracking
    bytes32 public immutable version;

    address public nttManagerBytecode1;
    address public nttManagerBytecode2;
    address public nttTransceiverBytecode;

    modifier onlyDeployer() {
        if (msg.sender != deployer) {
            revert NotDeployer();
        }
        _;
    }

    constructor(address deployerAddress, bytes32 currentVersion) {
        deployer = deployerAddress;
        version = currentVersion;
    }

    /// @inheritdoc INttFactory
    function initializeWormholeConfig(
        address whCoreBridge,
        address whRelayer,
        address whSpecialRelayer,
        uint16 whChainId
    ) external onlyDeployer {
        if (
            wormholeCoreBridge != address(0) || wormholeRelayer != address(0) || specialRelayer != address(0)
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

    /// @inheritdoc INttFactory
    function initializeTransceiverBytecode(bytes calldata transceiverBytecode) external onlyDeployer {
        if (transceiverBytecode.length == 0) {
            revert InvalidBytecodes();
        }
        if (nttTransceiverBytecode != address(0)) {
            revert TransceiverBytecodeAlreadyInitialized();
        }

        nttTransceiverBytecode = SSTORE2.write(transceiverBytecode);

        emit TransceiverBytecodeInitialized(keccak256(transceiverBytecode));
    }

    /// @inheritdoc INttFactory
    function initializeManagerBytecode(bytes calldata managerBytecode) external onlyDeployer {
        if (managerBytecode.length == 0) {
            revert InvalidBytecodes();
        }
        if (nttManagerBytecode1 != address(0) || nttManagerBytecode2 != address(0)) {
            revert ManagerBytecodeAlreadyInitialized();
        }
        uint256 mid = managerBytecode.length / 2;
        nttManagerBytecode1 = SSTORE2.write(managerBytecode[0:mid]);
        nttManagerBytecode2 = SSTORE2.write(managerBytecode[mid:]);

        emit ManagerBytecodeInitialized(keccak256(managerBytecode));
    }

    /// @inheritdoc INttFactory
    function deployNtt(
        IManagerBase.Mode mode,
        TokenParams memory tokenParams,
        string memory externalSalt,
        uint256 outboundLimit,
        PeerParams[] memory peerParams,
        bool createToken
    ) external payable returns (address token, address nttManager, address transceiver, address nttProxyOwnerAddress) {
        if (bytes(tokenParams.name).length == 0 || bytes(tokenParams.symbol).length == 0) {
            revert InvalidTokenParameters();
        }

        if (
            wormholeChainId == 0 || wormholeCoreBridge == address(0) || wormholeRelayer == address(0)
                || specialRelayer == address(0)
        ) {
            revert WormholeConfigNotInitialized();
        }

        if (
            nttManagerBytecode1 == address(0) || nttManagerBytecode2 == address(0)
                || nttTransceiverBytecode == address(0)
        ) {
            revert BytecodesNotInitialized();
        }
        address owner = msg.sender;
        token =
            createToken ? deployToken(tokenParams.name, tokenParams.symbol, externalSalt) : tokenParams.existingAddress;

        if (token == address(0)) {
            revert InvalidTokenParameters();
        }

        // deploy manager
        DeploymentParams memory params =
            DeploymentParams({token: token, mode: mode, outboundLimit: outboundLimit, externalSalt: externalSalt});
        nttManager = deployNttManager(params);

        if (params.mode == IManagerBase.Mode.BURNING && createToken) {
            configureTokenSettings(token, owner, tokenParams.initialSupply, nttManager);
        }

        // Don't skip rate limiting
        INttManager(nttManager).setOutboundLimit(params.outboundLimit);

        // Configure NttManager, but not ownership
        // To be able to call `configureNttTransceiver` from this factory
        configureNttManager(INttManager(nttManager), peerParams);

        // Deploy Wormhole Transceiver.
        transceiver = deployWormholeTransceiver(nttManager);

        // with the transceiver deployed, we are able to set it
        IManagerBase(nttManager).setTransceiver(transceiver);

        // Now transceiver can be configured from this factory
        configureNttTransceiver(
            IWormholeTransceiver(transceiver), peerParams, IWormhole(wormholeCoreBridge).messageFee()
        );

        // Deploy owner contract.
        NttProxyOwner ownerContract = NttProxyOwner(
            CREATE3.deployDeterministic(
                0,
                abi.encodePacked(type(NttProxyOwner).creationCode, abi.encode(owner)),
                keccak256(abi.encodePacked(nttManager, address(this), externalSalt, owner))
            )
        );

        // change ownership and pauser capability of nttManager and transceiver
        // to owner contract now that everything is configured
        PausableOwnable(nttManager).transferOwnership(address(ownerContract));
        PausableOwnable(nttManager).transferPauserCapability(address(ownerContract));
        PausableOwnable(transceiver).transferPauserCapability(address(ownerContract));

        emit ManagerDeployed(nttManager, token);
        emit TransceiverDeployed(transceiver, token);
        emit NttProxyOwnerDeployed(address(ownerContract), nttManager, transceiver);

        return (token, nttManager, transceiver, address(ownerContract));
    }

    /**
     * @notice Deploys a new token with 18 decimal precision
     * @dev Note: The deployed token will always have 18 decimals, regardless of
     *      the decimal precision of the same token on other chains. Ensure proper
     *      decimal handling when integrating across chains.
     */
    function deployToken(string memory name, string memory symbol, string memory externalSalt)
        internal
        returns (address)
    {
        bytes32 tokenSalt = keccak256(abi.encodePacked(version, msg.sender, name, symbol, externalSalt));

        // Deploy token. Initially we need to have minter and owner as this factory.
        address token = CREATE3.deployDeterministic(
            0,
            abi.encodePacked(type(PeerToken).creationCode, abi.encode(name, symbol, address(this), address(this))),
            tokenSalt
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

    function deployAndInitializeProxy(address implementation, bytes32 salt, uint256 msgValue)
        internal
        returns (address)
    {
        // Deploy deterministic proxy
        bytes memory proxyCreationCode =
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implementation, ""));

        address proxy = CREATE3.deployDeterministic(0, proxyCreationCode, salt);

        Implementation(proxy).initialize{value: msgValue}();

        return proxy;
    }

    function deployNttManager(DeploymentParams memory params) internal returns (address) {
        // We don't want to get the same bytecode if the token is the same, using externalSalt here too
        bytes32 implementationSalt =
            keccak256(abi.encodePacked(version, "MANAGER_IMPL", msg.sender, params.externalSalt, address(this)));

        bytes memory bytecode = abi.encodePacked(
            SSTORE2.read(nttManagerBytecode1),
            SSTORE2.read(nttManagerBytecode2),
            abi.encode(params.token, params.mode, wormholeChainId, RATE_LIMIT_DURATION, SHOULD_SKIP_RATE_LIMITER)
        );

        address implementation = Create2.deploy(0, implementationSalt, bytecode);

        // Get the same address across chains for the proxy. We can't use token address for hub and spoke
        bytes32 managerSalt = keccak256(abi.encodePacked(version, "MANAGER", msg.sender, params.externalSalt));

        return deployAndInitializeProxy(implementation, managerSalt, 0);
    }

    function deployWormholeTransceiver(address nttManager) internal returns (address) {
        bytes32 implementationSalt = keccak256(abi.encodePacked(version, "TRANSCEIVER_SALT", msg.sender, address(this)));

        bytes memory bytecode = abi.encodePacked(
            SSTORE2.read(nttTransceiverBytecode),
            abi.encode(nttManager, wormholeCoreBridge, wormholeRelayer, specialRelayer, CONSISTENCY_LEVEL, GAS_LIMIT)
        );
        address implementation = Create2.deploy(0, implementationSalt, bytecode);

        // Get the same address across chains for the proxy
        bytes32 transceiverSalt = keccak256(abi.encodePacked(version, "TRANSCEIVER", msg.sender, nttManager));
        uint256 messageFee = IWormhole(wormholeCoreBridge).messageFee();

        return deployAndInitializeProxy(implementation, transceiverSalt, messageFee);
    }

    function calculateFee(uint256 numberOfPeers) external view returns (uint256) {
        return (1 + numberOfPeers) * IWormhole(wormholeCoreBridge).messageFee();
    }

    /**
     * @inheritdoc INttFactory
     */
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(INttFactory).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
