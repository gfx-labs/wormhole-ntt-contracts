// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IManagerBase} from "native-token-transfers/interfaces/IManagerBase.sol";
import {PeersManager} from "./../PeersManager.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title INttFactory
 * @notice Interface for the NttFactory contract that deploys cross-chain NTT tokens and their managers
 */
interface INttFactory is IERC165 {
    // --- Structs ---
    struct TokenParams {
        string name;
        string symbol;
        address existingAddress;
        uint256 initialSupply;
    }

    struct DeploymentParams {
        address token;
        IManagerBase.Mode mode;
        uint256 outboundLimit;
        string externalSalt;
    }

    // --- Events ---
    event TokenDeployed(address indexed token, string name, string symbol);
    event ManagerDeployed(address indexed manager, address indexed token);
    event TransceiverDeployed(address indexed transceiver, address indexed token);
    event NttOwnerDeployed(address indexed ownerContract, address indexed manager, address indexed transceiver);
    event ManagerBytecodeInitialized(bytes32 managerBytecode);
    event TransceiverBytecodeInitialized(bytes32 transceiverBytecode);
    event WormholeConfigInitialized(address whCoreBridge, address whRelayer, address specialRelayer, uint16 whChainId);

    // --- Errors ---

    error NotDeployer();
    error InvalidBytecodes();
    error ManagerBytecodeAlreadyInitialized();
    error TransceiverBytecodeAlreadyInitialized();
    error BytecodesNotInitialized();
    error WormholeConfigAlreadyInitialized();
    error WormholeConfigNotInitialized();
    error InvalidTokenParameters();

    // --- Functions ---

    /**
     * @notice Returns the version of the factory
     * @return bytes32 representing the version
     */
    function version() external view returns (bytes32);

    /**
     * @notice Deploy a new NTT token, its manager and transceiver deterministically
     * @param mode Mode of the manager
     * @param tokenParams params to deploy or use existing params
     * @param externalSalt External salt used for deterministic deployment
     * @param outboundLimit Outbound limit for the new token
     * @param peerParams Peer parameters for the deployment
     * @return token Address of the deployed token
     * @return nttManager Address of the deployed manager
     * @return transceiver Address of the deployed transceiver
     * @return ownerContract Address of the contract that is owner of manager and transceiver
     */
    function deployNtt(
        IManagerBase.Mode mode,
        TokenParams memory tokenParams,
        string memory externalSalt,
        uint256 outboundLimit,
        PeersManager.PeerParams[] memory peerParams
    ) external payable returns (address token, address nttManager, address transceiver, address ownerContract);

    /**
     * @notice Initialize manager bytecode to be used on deploy of NTT manager
     * @param managerBytecode creationCode for the manager
     */
    function initializeManagerBytecode(bytes calldata managerBytecode) external;

    /**
     * @notice Initialize transceiver bytecode to be used on deploy of NTT transceiver
     * @param transceiverBytecode creationCode for the transceiver
     */
    function initializeTransceiverBytecode(bytes calldata transceiverBytecode) external;

    /**
     * @notice Initialize wormhole addresses for a given wormhole chain
     * @param whCoreBridge Wormhole core bridge
     * @param whRelayer Wormhole relayer
     * @param whSpecialRelayer Womrhole special relayer
     * @param whChainId Wormhole formatted chainId
     */
    function initializeWormholeConfig(
        address whCoreBridge,
        address whRelayer,
        address whSpecialRelayer,
        uint16 whChainId
    ) external;

    /**
     * @notice Implements ERC165 to declare support for interfaces
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return bool True if the contract implements the requested interface
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
