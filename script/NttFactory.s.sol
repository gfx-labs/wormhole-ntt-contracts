// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {NttFactory} from "../src/NttFactory.sol";
import {INttFactory} from "../src/interfaces/INttFactory.sol";
import {IWormhole} from "wormhole-solidity-sdk/interfaces/IWormhole.sol";

contract NttFactoryDeploy is Script {
    function run() public payable {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        bytes32 salt = keccak256(abi.encodePacked(deployer));

        INttFactory.ConstructorParams memory constructorParams = INttFactory.ConstructorParams({
            wormholeCoreBridge: vm.envAddress("WORMHOLE_CORE_BRIDGE"),
            wormholeRelayer: vm.envAddress("WORMHOLE_RELAYER"),
            specialRelayer: vm.envAddress("SPECIAL_RELAYER"),
            whChainId: IWormhole(vm.envAddress("WORMHOLE_CORE_BRIDGE")).chainId()
        });

        vm.startBroadcast(deployerPrivateKey);
        NttFactory factory = new NttFactory{salt: salt}(constructorParams);
        vm.stopBroadcast();
        console2.log("Factory deployed to:", address(factory));
    }
}
