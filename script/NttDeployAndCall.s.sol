// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {NttFactory} from "../src/NttFactory.sol";
import {NttManager} from "vendor/NttManager/NttManager.sol";
import {WormholeTransceiver} from "vendor/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

contract NttDeployAndCall is Script {
    function run() public payable {
        deployBaseSepolia();
        //deployEthSepolia();
        //deployOpSepolia();
    }

    function deployBaseSepolia() internal {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address nttFactory = vm.envAddress("NTT_FACTORY");

        // Base Sepolia
        vm.createSelectFork("base-sepolia");
        NttFactory.EnvParams memory envParamsBaseSepolia = NttFactory.EnvParams({
            wormholeCoreBridge: vm.envAddress("WORMHOLE_CORE_BRIDGE_BASE_SEPOLIA"),
            wormholeRelayerAddr: vm.envAddress("WORMHOLE_RELAYER_ADDR_BASE_SEPOLIA"),
            specialRelayerAddr: vm.envAddress("SPECIAL_RELAYER_ADDR_BASE_SEPOLIA")
        });

        vm.startBroadcast(deployerPrivateKey);
        NttFactory factoryBaseSepolia = NttFactory(nttFactory);
        factoryBaseSepolia.deployNtt(
            "token",
            "TKN",
            msg.sender,
            msg.sender,
            envParamsBaseSepolia,
            type(NttManager).creationCode,
            type(WormholeTransceiver).creationCode
        );
        vm.stopBroadcast();
        console2.log("Base Sepolia deployment completed.");
    }

    // function deployEthSepolia() internal {
    //     uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    //     address nttFactory = vm.envAddress("NTT_FACTORY");

    //     // Eth Sepolia
    //     vm.createSelectFork("eth-sepolia");
    //     NttFactory.EnvParams memory envParamsEthSepolia = NttFactory.EnvParams({
    //         wormholeCoreBridge: vm.envAddress("WORMHOLE_CORE_BRIDGE_ETH_SEPOLIA"),
    //         wormholeRelayerAddr: vm.envAddress("WORMHOLE_RELAYER_ADDR_ETH_SEPOLIA"),
    //         specialRelayerAddr: vm.envAddress("SPECIAL_RELAYER_ADDR_ETH_SEPOLIA")
    //     });

    //     vm.startBroadcast(deployerPrivateKey);
    //     NttFactory factoryEthSepolia = NttFactory(nttFactory);
    //     factoryEthSepolia.deployNtt(
    //         "token",
    //         "TKN",
    //         msg.sender,
    //         msg.sender,
    //         envParamsEthSepolia,
    //         type(NttManager).creationCode,
    //         type(WormholeTransceiver).creationCode
    //     );
    //     vm.stopBroadcast();
    //     console2.log("Eth Sepolia deployment completed.");
    // }

    // function deployOpSepolia() internal {
    //     uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    //     address nttFactory = vm.envAddress("NTT_FACTORY");

    //     // Op Sepolia
    //     vm.createSelectFork("op-sepolia");
    //     NttFactory.EnvParams memory envParamsOpSepolia = NttFactory.EnvParams({
    //         wormholeCoreBridge: vm.envAddress("WORMHOLE_CORE_BRIDGE_OP_SEPOLIA"),
    //         wormholeRelayerAddr: vm.envAddress("WORMHOLE_RELAYER_ADDR_OP_SEPOLIA"),
    //         specialRelayerAddr: vm.envAddress("SPECIAL_RELAYER_ADDR_OP_SEPOLIA")
    //     });

    //     vm.startBroadcast(deployerPrivateKey);
    //     NttFactory factoryOpSepolia = NttFactory(nttFactory);
    //     factoryOpSepolia.deployNtt(
    //         "token",
    //         "TKN",
    //         msg.sender,
    //         msg.sender,
    //         envParamsOpSepolia,
    //         type(NttManager).creationCode,
    //         type(WormholeTransceiver).creationCode
    //     );
    //     vm.stopBroadcast();
    //     console2.log("Op Sepolia deployment completed.");
    // }
}
