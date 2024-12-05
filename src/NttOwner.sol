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
    constructor(address owner) Ownable(owner) {}

    /**
     * @notice Sets the peers for the NTT Manager and NTT Transceiver
     * @param nttManager The address of the NTT Manager contract
     * @param nttTransceiver The address of the NTT Transceiver contract
     * @param peerParams The parameters for the peers
     */
    function setPeers(address nttManager, address nttTransceiver, PeersLibrary.PeerParams[] memory peerParams)
        external
        onlyOwner
    {
        PeersLibrary.configureNttManager(INttManager(nttManager), peerParams);
        PeersLibrary.configureNttTransceiver(IWormholeTransceiver(nttTransceiver), peerParams);
    }

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
        onlyOwner
        returns (bool success, bytes memory result)
    {
        bytes memory completeCalldata = abi.encodePacked(selector, data);

        (success, result) = target.call(completeCalldata);

        return (success, result);
    }
}
