// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {Script, console2} from "forge-std/Script.sol";
import {NttFactory} from "../src/NttFactory.sol";
import {IWormhole} from "wormhole-solidity-sdk/interfaces/IWormhole.sol";
import {NttManager} from "native-token-transfers/NttManager/NttManager.sol";
import {WormholeTransceiver} from "native-token-transfers/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

contract NttFactoryDeploy is Script {
    function run() public payable {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        bytes32 salt = keccak256(abi.encodePacked(deployer, block.timestamp));

        address wormholeCoreBridge = vm.envAddress("WORMHOLE_CORE_BRIDGE");
        // TODO: Relayers are deprecated and will be removed once NttManager is updated
        // Using address(0) for now
        address wormholeRelayer = address(0);
        address specialRelayer = address(0);
        bytes32 currentVersion = bytes32(bytes(vm.envString("VERSION")));

        uint16 whChainId = IWormhole(wormholeCoreBridge).chainId();

        console2.log("=== Deployment Configuration ===");
        console2.log("Deployer:", deployer);
        console2.log("Wormhole Core Bridge:", wormholeCoreBridge);
        console2.log("Chain ID:", whChainId);
        console2.log("Version:", vm.toString(currentVersion));
        console2.log("================================");

        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deploying NttFactory...");
        NttFactory factory = new NttFactory{salt: salt}(deployer, currentVersion);
        console2.log("Factory deployed to:", address(factory));

        console2.log("Initializing Manager Bytecode...");
        factory.initializeManagerBytecode(type(NttManager).creationCode);
        console2.log("Manager bytecode initialized");

        console2.log("Initializing Transceiver Bytecode...");
        factory.initializeTransceiverBytecode(type(WormholeTransceiver).creationCode);
        console2.log("Transceiver bytecode initialized");

        console2.log("Initializing Wormhole Config...");
        factory.initializeWormholeConfig(wormholeCoreBridge, wormholeRelayer, specialRelayer, whChainId);
        console2.log("Wormhole config initialized");

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== Deployment Complete ===");
        console2.log("Factory Address:", address(factory));
        console2.log("===========================");
    }
}
