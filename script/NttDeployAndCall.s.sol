// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {NttFactory} from "../src/NttFactory.sol";
import {NttManager} from "vendor/NttManager/NttManager.sol";
import {WormholeTransceiver} from "vendor/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

contract NttDeployAndCall is Script {
    function run() public payable {
        NttFactory.EnvParams memory envParamsBaseSepolia = NttFactory.EnvParams({
            wormholeCoreBridge: vm.envAddress("WORMHOLE_CORE_BRIDGE_BASE_SEPOLIA"),
            wormholeRelayerAddr: vm.envAddress("WORMHOLE_RELAYER_ADDR_BASE_SEPOLIA"),
            specialRelayerAddr: vm.envAddress("SPECIAL_RELAYER_ADDR_BASE_SEPOLIA")
        });

        NttFactory.EnvParams memory envParamsEthSepolia = NttFactory.EnvParams({
            wormholeCoreBridge: vm.envAddress("WORMHOLE_CORE_BRIDGE_ETH_SEPOLIA"),
            wormholeRelayerAddr: vm.envAddress("WORMHOLE_RELAYER_ADDR_ETH_SEPOLIA"),
            specialRelayerAddr: vm.envAddress("SPECIAL_RELAYER_ADDR_ETH_SEPOLIA")
        });

        NttFactory.EnvParams memory envParamsOpSepolia = NttFactory.EnvParams({
            wormholeCoreBridge: vm.envAddress("WORMHOLE_CORE_BRIDGE_OP_SEPOLIA"),
            wormholeRelayerAddr: vm.envAddress("WORMHOLE_RELAYER_ADDR_OP_SEPOLIA"),
            specialRelayerAddr: vm.envAddress("SPECIAL_RELAYER_ADDR_OP_SEPOLIA")
        });

        uint16 sepolia = 10002;
        uint16 baseSepolia = 10004;

        // deploy(envParamsBaseSepolia, sepolia);
        deploy(envParamsEthSepolia, baseSepolia);
    }

    function deploy(NttFactory.EnvParams memory envParams, uint16 peerChainId) internal {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address nttFactory = vm.envAddress("NTT_FACTORY");

        uint256 initialSupply = 1000000000000000000000;
        uint256 inboundLimit = 1000000000000000000000;
        uint8 decimals = 18;

        NttFactory.PeerParams[] memory peerParams = new NttFactory.PeerParams[](1);
        peerParams[0] =
            NttFactory.PeerParams({peerChainId: peerChainId, decimals: decimals, inboundLimit: inboundLimit});

        vm.startBroadcast(deployerPrivateKey);
        NttFactory factoryBaseSepolia = NttFactory(nttFactory);
        factoryBaseSepolia.deployNtt(
            "token3",
            "TKN",
            initialSupply,
            initialSupply,
            envParams,
            peerParams,
            type(NttManager).creationCode,
            type(WormholeTransceiver).creationCode
        );
        vm.stopBroadcast();
        console2.log("Base Sepolia deployment completed.");
    }
}
