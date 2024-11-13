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

        // Base Sepolia
        vm.createSelectFork("base-sepolia");
        vm.startBroadcast(deployerPrivateKey);
        NttFactory factoryBaseSepolia = new NttFactory{salt: salt}(VERSION);
        vm.stopBroadcast();
        console2.log("Base Sepolia Factory deployed to:", address(factoryBaseSepolia));

        // Eth Sepolia
        vm.createSelectFork("eth-sepolia");
        vm.startBroadcast(deployerPrivateKey);
        NttFactory factoryEthSepolia = new NttFactory{salt: salt}(VERSION);
        vm.stopBroadcast();
        console2.log("Eth Sepolia Factory deployed to:", address(factoryEthSepolia));

        // Op Sepolia
        vm.createSelectFork("opt-sepolia");
        vm.startBroadcast(deployerPrivateKey);
        NttFactory factoryOpSepolia = new NttFactory{salt: salt}(VERSION);
        vm.stopBroadcast();
        console2.log("Op Sepolia Factory deployed to:", address(factoryOpSepolia));
    }
}
