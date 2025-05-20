// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

struct Call3Value {
    address target;
    bool allowFailure;
    uint256 value;
    bytes callData;
}

struct Result {
    bool success;
    bytes returnData;
}

/**
 * @title INttProxyOwner
 * @notice Interface for the NttProxyOwner contract
 */
interface INttProxyOwner is IERC165 {
    /**
     * @notice Executes a call to a target contract with specified function selector and calldata
     * @param target The address of the contract to call
     * @param completeCalldata The calldata for the function call
     * @return result The returned data from the call
     */
    function execute(address target, bytes calldata completeCalldata) external payable returns (bytes memory result);

    /**
     * @notice Executes multiple calls to target contracts with specified function selectors and calldata
     * @param calls The array of calls to execute
     * @return results The array of returned data from the calls
     */
    function executeMany(Call3Value[] calldata calls) external payable returns (Result[] memory results);

    /**
     * @notice implementations should return true if they are NttProxyOwner
     * @return bool True if the contract is NttProxyOwner
     */
    function isNttProxyOwner() external view returns (bool);

    /**
     * @notice Implements ERC165 to declare support for interfaces
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return bool True if the contract implements the requested interface
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

