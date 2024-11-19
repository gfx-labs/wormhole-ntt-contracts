// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {NttFactory} from "../src/NttFactory.sol";

contract NttFactoryDeploy is Script {
    function run() public payable {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        bytes32 VERSION = keccak256(abi.encodePacked(vm.envString("VERSION")));
        bytes32 salt = keccak256(abi.encodePacked(deployer, VERSION));

        vm.startBroadcast(deployerPrivateKey);
        NttFactory factory = new NttFactory{salt: salt}(VERSION);
        vm.stopBroadcast();
        console2.log("Factory deployed to:", address(factory));
    }
}
