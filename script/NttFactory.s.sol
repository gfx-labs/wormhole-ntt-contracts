// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {NttFactory} from "../src/NttFactory.sol";
import {CREATE3Factory} from "lib/create3-factory/src/CREATE3Factory.sol";

contract NttFactoryDeploy is Script {
    function run() public payable {
        CREATE3Factory create3Factory = CREATE3Factory(0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf);

        bytes32 VERSION = keccak256(abi.encodePacked(vm.envString("VERSION")));

        // Hardcoded EnvParams from environment variables
        // address wormholeCoreBridge = vm.envAddress("WORMHOLE_CORE_BRIDGE");
        // address wormholeRelayerAddr = vm.envAddress("WORMHOLE_RELAYER_ADDR");
        // address specialRelayerAddr = vm.envAddress("SPECIAL_RELAYER_ADDR");

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        // Each deployer with its own namespace
        bytes32 FACTORY_SALT = keccak256(abi.encodePacked(deployer, VERSION));

        console2.log("Deploying factory with private key:", deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        NttFactory factory = NttFactory(
            create3Factory.deploy(
                FACTORY_SALT, abi.encodePacked(type(NttFactory).creationCode, abi.encode(deployer, VERSION))
            )
        );

        vm.stopBroadcast();

        console2.log("Factory deployed to:", address(factory));
    }
}
