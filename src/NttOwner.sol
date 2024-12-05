// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IWormholeTransceiver} from "native-token-transfers/interfaces/IWormholeTransceiver.sol";
import {INttManager} from "native-token-transfers/interfaces/INttManager.sol";
import {PeersLibrary} from "./PeersLibrary.sol";
import {INttOwner} from "./interfaces/INttOwner.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title NttOwner
 * @notice Owner contract to provide helpers to NTT deployed contracts
 */
contract NttOwner is Ownable, INttOwner {
    constructor(address owner) Ownable(owner) {}

    /**
     * @inheritdoc INttOwner
     */
    function setPeers(address nttManager, address nttTransceiver, PeersLibrary.PeerParams[] memory peerParams)
        external
        onlyOwner
    {
        PeersLibrary.configureNttManager(INttManager(nttManager), peerParams);
        PeersLibrary.configureNttTransceiver(IWormholeTransceiver(nttTransceiver), peerParams);
    }

    /**
     * @inheritdoc INttOwner
     */
    function execute(address target, bytes4 selector, bytes calldata data)
        external
        onlyOwner
        returns (bool success, bytes memory result)
    {
        bytes memory completeCalldata = abi.encodePacked(selector, data);

        (success, result) = target.call(completeCalldata);

        return (success, result);
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(INttOwner).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
