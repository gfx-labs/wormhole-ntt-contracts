// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IWormholeTransceiver} from "native-token-transfers/interfaces/IWormholeTransceiver.sol";
import {INttManager} from "native-token-transfers/interfaces/INttManager.sol";
import {PeersManager} from "./PeersManager.sol";
import {INttOwner} from "./interfaces/INttOwner.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title NttOwner
 * @notice Owner contract to provide helpers to NTT deployed contracts
 */
contract NttOwner is Ownable, PeersManager, INttOwner {
    constructor(address owner) Ownable(owner) {}

    /**
     * @inheritdoc INttOwner
     */
    function setPeers(address nttManager, address nttTransceiver, PeersManager.PeerParams[] memory peerParams)
        external
        payable
        onlyOwner
    {
        configureNttManager(INttManager(nttManager), peerParams);
        configureNttTransceiver(IWormholeTransceiver(nttTransceiver), peerParams, msg.value);
    }

    /**
     * @inheritdoc INttOwner
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
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(INttOwner).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
