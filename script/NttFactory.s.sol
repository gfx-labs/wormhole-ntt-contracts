// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {CREATE3} from "solmate/utils/CREATE3.sol";

import {NttFactory} from "../src/NttFactory.sol";

contract NttFactoryScript is Script {
    function setUp() public {}

    function run() public payable {
        bytes32 VERSION = keccak256("V0"); // Take from env

        // Each deployer with its own namespace
        bytes32 FACTORY_SALT = keccak256(abi.encodePacked(msg.sender, VERSION));

        vm.startBroadcast();

        NttFactory factory = NttFactory(
            CREATE3.deploy(
                FACTORY_SALT, abi.encodePacked(type(NttFactory).creationCode, abi.encode(msg.sender)), msg.value
            )
        );

        vm.stopBroadcast();

        console2.log("Factory deployed to:", address(factory));
    }
}
