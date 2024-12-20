// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IManagerBase} from "native-token-transfers/interfaces/IManagerBase.sol";
import {PeersLibrary} from "./../PeersLibrary.sol";
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
    event PeerSet(address indexed manager, uint16 chainId, bytes32 peer);

    // --- Errors ---
    error DeploymentFailed();
    error InvalidParameters();

    // --- Functions ---

    /**
     * @notice Returns the version of the factory
     * @return bytes32 representing the version
     */
    function VERSION() external view returns (bytes32);

    /**
     * @notice Deploy a new NTT token, its manager and transceiver deterministically
     * @param mode Mode of the manager
     * @param tokenParams params to deploy or use existing params
     * @param externalSalt External salt used for deterministic deployment
     * @param outboundLimit Outbound limit for the new token
     * @param peerParams Peer parameters for the deployment
     * @param nttManagerBytecode Bytecode of the NTT manager
     * @param nttTransceiverBytecode Bytecode of the NTT transceiver
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
        PeersLibrary.PeerParams[] memory peerParams,
        bytes memory nttManagerBytecode,
        bytes memory nttTransceiverBytecode
    ) external returns (address token, address nttManager, address transceiver, address ownerContract);

    /**
     * @notice Implements ERC165 to declare support for interfaces
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return bool True if the contract implements the requested interface
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
