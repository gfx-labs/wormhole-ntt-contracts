// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {NttFactory} from "../src/NttFactory.sol";
import {PeersLibrary} from "../src/PeersLibrary.sol";

import {NttManager} from "native-token-transfers/NttManager/NttManager.sol";
import {WormholeTransceiver} from "native-token-transfers/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";
import {IManagerBase} from "native-token-transfers/interfaces/IManagerBase.sol";
import {INttFactory} from "../src/interfaces/INttFactory.sol";

contract NttDeployAndCall is Script {
    function run() public payable {
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

        INttFactory.EnvParams memory envParamsArbSepolia = INttFactory.EnvParams({
            wormholeCoreBridge: vm.envAddress("WORMHOLE_CORE_BRIDGE_ARB_SEPOLIA"),
            wormholeRelayerAddr: vm.envAddress("WORMHOLE_RELAYER_ADDR_ARB_SEPOLIA"),
            specialRelayerAddr: vm.envAddress("SPECIAL_RELAYER_ADDR_ARB_SEPOLIA")
        });

        // INttFactory.EnvParams memory envParamsOpSepolia = INttFactory.EnvParams({
        //     wormholeCoreBridge: vm.envAddress("WORMHOLE_CORE_BRIDGE_OP_SEPOLIA"),
        //     wormholeRelayerAddr: vm.envAddress("WORMHOLE_RELAYER_ADDR_OP_SEPOLIA"),
        //     specialRelayerAddr: vm.envAddress("SPECIAL_RELAYER_ADDR_OP_SEPOLIA")
        // });

        // uint16 sepolia = 10002;
        uint16 baseSepolia = 10004;
        //uint16 arbSepolia = 10003;

        // deploy(envParamsBaseSepolia, sepolia);
        deploy(envParamsArbSepolia, baseSepolia);
    }

    function deploy(INttFactory.EnvParams memory envParams, uint16 peerChainId) internal {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address nttFactory = vm.envAddress("NTT_FACTORY");

        uint256 initialSupply = 1000000000000000000000;
        uint256 inboundLimit = 1000000000000000000000;
        uint8 decimals = 18;

        PeersLibrary.PeerParams[] memory peerParams = new PeersLibrary.PeerParams[](1);
        peerParams[0] =
            PeersLibrary.PeerParams({peerChainId: peerChainId, decimals: decimals, inboundLimit: inboundLimit});

        vm.startBroadcast(deployerPrivateKey);
        address zeroTokenAddress = 0x0000000000000000000000000000000000000000;

        INttFactory.TokenParams memory tokenParams = INttFactory.TokenParams({
            name: "token",
            symbol: "TKN",
            existingAddress: zeroTokenAddress,
            initialSupply: initialSupply
        });

        NttFactory factoryBaseSepolia = NttFactory(nttFactory);
        factoryBaseSepolia.deployNtt(
            IManagerBase.Mode.BURNING,
            tokenParams,
            "salt",
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
