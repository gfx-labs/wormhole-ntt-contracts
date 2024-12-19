// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {CREATE3} from "solmate/utils/CREATE3.sol";

import {NttManager} from "native-token-transfers/NttManager/NttManager.sol";
import {PausableOwnable} from "native-token-transfers/libraries/PausableOwnable.sol";
import {WormholeTransceiver} from "native-token-transfers/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";
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
    bytes32 public immutable VERSION;

    constructor(bytes32 _version) {
        if (_version == bytes32(0)) revert InvalidParameters();
        VERSION = _version;
    }

    /// @inheritdoc INttFactory
    function deployNtt(
        IManagerBase.Mode mode,
        TokenParams memory tokenParams,
        string memory externalSalt,
        uint256 outboundLimit,
        EnvParams memory envParams,
        PeersLibrary.PeerParams[] memory peerParams,
        bytes memory nttManagerBytecode,
        bytes memory nttTransceiverBytecode
    ) external returns (address token, address nttManager, address transceiver, address _ownerContract) {
        if (bytes(tokenParams.name).length == 0 || bytes(tokenParams.symbol).length == 0) revert InvalidParameters();

        address owner = msg.sender;

        NttOwner ownerContract = new NttOwner(owner);

        token = (mode == IManagerBase.Mode.BURNING)
            ? deployToken(tokenParams.name, tokenParams.symbol, externalSalt)
            : tokenParams.existingAddress;

        // deploy manager
        DeploymentParams memory params = DeploymentParams({
            token: token,
            mode: mode,
            wormholeChainId: IWormhole(envParams.wormholeCoreBridge).chainId(),
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
            configureTokenSettings(token, owner, tokenParams.initialSupply, nttManager);
        }

        // Configure NttManager, but not ownership
        // To be able to call `configureNttTransceiver` from this factory
        if (!params.shouldSkipRatelimiter) {
            INttManager(nttManager).setOutboundLimit(params.outboundLimit);
        }
        PeersLibrary.configureNttManager(INttManager(nttManager), peerParams);

        // Deploy Wormhole Transceiver.
        transceiver = deployWormholeTransceiver(params, nttManager, nttTransceiverBytecode);

        // with the transceiver deployed, we are able to set it
        IManagerBase(nttManager).setTransceiver(transceiver);

        // As is only one transceiver now, with set to 1
        INttManager(nttManager).setThreshold(1);

        // Now transceiver can be configured from this factory
        PeersLibrary.configureNttTransceiver(IWormholeTransceiver(transceiver), peerParams);

        // change ownership of nttManager to tokenOwner now that everything is configured
        PausableOwnable(nttManager).transferPauserCapability(address(ownerContract));
        PausableOwnable(nttManager).transferOwnership(address(ownerContract));

        emit ManagerDeployed(nttManager, token);
        emit TransceiverDeployed(transceiver, token);
        emit NttOwnerDeployed(address(ownerContract), nttManager, transceiver);

        return (token, nttManager, transceiver, address(ownerContract));
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

    /**
     * @inheritdoc INttFactory
     */
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(INttFactory).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
