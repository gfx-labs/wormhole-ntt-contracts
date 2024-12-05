// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {PeersLibrary} from "./../PeersLibrary.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title INttOwner
 * @notice Interface for the NttOwner contract
 */
interface INttOwner is IERC165 {
    /**
     * @notice Sets the peers for the NTT Manager and NTT Transceiver
     * @param nttManager The address of the NTT Manager contract
     * @param nttTransceiver The address of the NTT Transceiver contract
     * @param peerParams The parameters for the peers
     */
    function setPeers(address nttManager, address nttTransceiver, PeersLibrary.PeerParams[] memory peerParams)
        external;

    /**
     * @notice Executes a call to a target contract with specified function selector and calldata
     * @param target The address of the contract to call
     * @param selector The function selector to call
     * @param data The calldata for the function call
     * @return success Boolean indicating if the call was successful
     * @return result The returned data from the call
     */
    function execute(address target, bytes4 selector, bytes calldata data)
        external
        returns (bool success, bytes memory result);

    /**
     * @notice Implements ERC165 to declare support for interfaces
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return bool True if the contract implements the requested interface
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
