// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IWormholeTransceiver} from "native-token-transfers/interfaces/IWormholeTransceiver.sol";
import {INttManager} from "native-token-transfers/interfaces/INttManager.sol";
import {PeersManager} from "./PeersManager.sol";
import {INttProxyOwner, Call3Value, Result} from "./interfaces/INttProxyOwner.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title NttProxyOwner
 * @notice Owner contract to provide helpers to NTT deployed contracts
 */
contract NttProxyOwner is Ownable, INttProxyOwner {
    constructor(address owner) Ownable(owner) {}

    /**
     * @inheritdoc INttProxyOwner
     */
    function execute(address target, bytes calldata completeCalldata)
        external
        payable
        onlyOwner
        returns (bytes memory result)
    {
        (result) = Address.functionCallWithValue(target, completeCalldata, msg.value);
    }

    /**
     * @inheritdoc INttProxyOwner
     * @dev this is copied from https://github.com/mds1/multicall3/blob/v3.1.0/src/Multicall3.sol
     */
    function executeMany(Call3Value[] calldata calls) external payable onlyOwner returns (Result[] memory returnData) {
        uint256 valAccumulator;
        uint256 length = calls.length;
        returnData = new Result[](length);
        Call3Value calldata calli;
        for (uint256 i = 0; i < length;) {
            Result memory result = returnData[i];
            calli = calls[i];
            uint256 val = calli.value;
            // Humanity will be a Type V Kardashev Civilization before this overflows - andreas
            // ~ 10^25 Wei in existence << ~ 10^76 size uint fits in a uint256
            unchecked {
                valAccumulator += val;
            }
            (result.success, result.returnData) = calli.target.call{value: val}(calli.callData);
            assembly {
                // Revert if the call fails and failure is not allowed
                // `allowFailure := calldataload(add(calli, 0x20))` and `success := mload(result)`
                if iszero(or(calldataload(add(calli, 0x20)), mload(result))) {
                    // set "Error(string)" signature: bytes32(bytes4(keccak256("Error(string)")))
                    mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    // set data offset
                    mstore(0x04, 0x0000000000000000000000000000000000000000000000000000000000000020)
                    // set length of revert string
                    mstore(0x24, 0x0000000000000000000000000000000000000000000000000000000000000017)
                    // set revert string: bytes32(abi.encodePacked("Multicall3: call failed"))
                    mstore(0x44, 0x4d756c746963616c6c333a2063616c6c206661696c6564000000000000000000)
                    revert(0x00, 0x84)
                }
            }
            unchecked {
                ++i;
            }
        }
        // Finally, make sure the msg.value = SUM(call[0...i].value)
        require(msg.value == valAccumulator, "Multicall3: value mismatch");
    }

    /**
     * @inheritdoc INttProxyOwner
     */
    function isNttProxyOwner() external pure returns (bool) {
        return true;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(INttProxyOwner).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
