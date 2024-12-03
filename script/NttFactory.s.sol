// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {NttFactory} from "../src/NttFactory.sol";
import {INttFactory} from "../src/interfaces/INttFactory.sol";

import {NttManager} from "native-token-transfers/NttManager/NttManager.sol";
import {WormholeTransceiver} from "native-token-transfers/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

contract NttFactoryDeploy is Script {
    function run() public payable {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        bytes32 VERSION = keccak256(abi.encodePacked(vm.envString("VERSION")));
        bytes32 salt = keccak256(abi.encodePacked(deployer, VERSION));

        // INttFactory.EnvParams memory envParamsBaseSepolia = INttFactory.EnvParams({
        //     wormholeCoreBridge: vm.envAddress("WORMHOLE_CORE_BRIDGE_BASE_SEPOLIA"),
        //     wormholeRelayerAddr: vm.envAddress("WORMHOLE_RELAYER_ADDR_BASE_SEPOLIA"),
        //     specialRelayerAddr: vm.envAddress("SPECIAL_RELAYER_ADDR_BASE_SEPOLIA")
        // });

        // INttFactory.EnvParams memory envParamsEthSepolia = INttFactory.EnvParams({
        //     wormholeCoreBridge: vm.envAddress("WORMHOLE_CORE_BRIDGE_ETH_SEPOLIA"),
        //     wormholeRelayerAddr: vm.envAddress("WORMHOLE_RELAYER_ADDR_ETH_SEPOLIA"),
        //     specialRelayerAddr: vm.envAddress("SPECIAL_RELAYER_ADDR_ETH_SEPOLIA")
        // });

        INttFactory.EnvParams memory envParamsOpSepolia = INttFactory.EnvParams({
            wormholeCoreBridge: vm.envAddress("WORMHOLE_CORE_BRIDGE_OP_SEPOLIA"),
            wormholeRelayerAddr: vm.envAddress("WORMHOLE_RELAYER_ADDR_OP_SEPOLIA"),
            specialRelayerAddr: vm.envAddress("SPECIAL_RELAYER_ADDR_OP_SEPOLIA")
        });

        // INttFactory.EnvParams memory envParams = INttFactory.EnvParams({
        //     wormholeCoreBridge: vm.envAddress("WORMHOLE_CORE_BRIDGE_ARB_SEPOLIA"),
        //     wormholeRelayerAddr: vm.envAddress("WORMHOLE_RELAYER_ADDR_ARB_SEPOLIA"),
        //     specialRelayerAddr: vm.envAddress("SPECIAL_RELAYER_ADDR_ARB_SEPOLIA")
        // });

        vm.startBroadcast(deployerPrivateKey);
        NttFactory factory = new NttFactory{salt: salt}(VERSION, deployer);

        factory.setNttManagerBytecode(type(NttManager).creationCode);
        factory.setWhTransceiverBytecode(type(WormholeTransceiver).creationCode);
        factory.setWhAddresses(envParamsOpSepolia);

        vm.stopBroadcast();
        console2.log("Factory deployed to:", address(factory));
    }
}
