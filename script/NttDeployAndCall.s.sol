// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {NttFactory} from "../src/NttFactory.sol";
import {NttManager} from "vendor/NttManager/NttManager.sol";
import {WormholeTransceiver} from "vendor/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

contract NttDeployAndCall is Script {
    function run() public payable {
        // Hardcoded EnvParams from environment variables
        address wormholeCoreBridge = vm.envAddress("WORMHOLE_CORE_BRIDGE");
        address wormholeRelayerAddr = vm.envAddress("WORMHOLE_RELAYER_ADDR");
        address specialRelayerAddr = vm.envAddress("SPECIAL_RELAYER_ADDR");

        address nttFactory = vm.envAddress("NTT_FACTORY");

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        bytes32 VERSION = keccak256(abi.encodePacked(vm.envString("VERSION")));
        bytes32 salt = keccak256(abi.encodePacked(deployer, VERSION));

        NttFactory.EnvParams memory envParams = NttFactory.EnvParams({
            wormholeCoreBridge: wormholeCoreBridge,
            wormholeRelayerAddr: wormholeRelayerAddr,
            specialRelayerAddr: specialRelayerAddr
        });

        vm.startBroadcast(deployerPrivateKey);
        NttFactory factory = NttFactory(nttFactory);
        factory.deployNtt(
            "token",
            "TKN",
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
