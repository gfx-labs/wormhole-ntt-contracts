// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IWormholeTransceiver} from "native-token-transfers/interfaces/IWormholeTransceiver.sol";
import {INttManager} from "native-token-transfers/interfaces/INttManager.sol";
import {PeersLibrary} from "./PeersLibrary.sol";

/**
 * @title NttOwner
 * @notice Owner contract to provide helpers to NTT deployed contracts
 */
contract NttOwner is Ownable {
    constructor() Ownable(msg.sender) {}

    // TODO execute

    function setPeers(address nttManager, address nttTransceiver, PeersLibrary.PeerParams[] memory peerParams)
        external
        onlyOwner
    {
        PeersLibrary.configureNttManager(INttManager(nttManager), peerParams);
        PeersLibrary.configureNttTransceiver(IWormholeTransceiver(nttTransceiver), peerParams);
    }
}
