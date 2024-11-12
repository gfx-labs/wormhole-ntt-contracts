// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {NttFactory} from "../src/NttFactory.sol";
import {NttManager} from "vendor/NttManager/NttManager.sol";
import {WormholeTransceiver} from "vendor/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

contract NttDeployAndCall is Script {
    function run() public payable {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address nttFactory = vm.envAddress("NTT_FACTORY");

        NttFactory.EnvParams memory envParams = NttFactory.EnvParams({
            wormholeCoreBridge: vm.envAddress("WORMHOLE_CORE_BRIDGE"),
            wormholeRelayerAddr: vm.envAddress("WORMHOLE_RELAYER_ADDR"),
            specialRelayerAddr: vm.envAddress("SPECIAL_RELAYER_ADDR")
        });

        vm.startBroadcast(deployerPrivateKey);

        NttFactory factory = NttFactory(nttFactory);
        factory.deployNtt(
            "token1",
            "TKN1",
            msg.sender,
            msg.sender,
            envParams,
            type(NttManager).creationCode,
            type(WormholeTransceiver).creationCode
        );

        vm.stopBroadcast();

        console2.log("Factory deployed to:", address(factory));
    }
}
