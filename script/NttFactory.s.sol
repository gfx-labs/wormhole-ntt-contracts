// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {CREATE3} from "solmate/utils/CREATE3.sol";
import {NttFactory} from "../src/NttFactory.sol";

contract NttFactoryDeploy is Script {
    function setUp() public {}

    function run() public payable {
        bytes32 VERSION = keccak256(abi.encodePacked(vm.envString("VERSION")));

        // Each deployer with its own namespace
        bytes32 FACTORY_SALT = keccak256(abi.encodePacked(msg.sender, VERSION));

        // Hardcoded EnvParams from environment variables
        address wormholeCoreBridge = vm.envAddress("WORMHOLE_CORE_BRIDGE");
        address wormholeRelayerAddr = vm.envAddress("WORMHOLE_RELAYER_ADDR");
        address specialRelayerAddr = vm.envAddress("SPECIAL_RELAYER_ADDR");

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        console2.log("Deploying factory with private key:", deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        NttFactory factory = NttFactory(
            CREATE3.deploy(
                FACTORY_SALT,
                abi.encodePacked(type(NttFactory).creationCode, abi.encode(msg.sender, VERSION)),
                msg.value
            )
        );

        vm.stopBroadcast();

        console2.log("Factory deployed to:", address(factory));
    }
}
