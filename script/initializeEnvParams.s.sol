// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {Script, console2} from "forge-std/Script.sol";
import {NttFactory} from "../src/NttFactory.sol";
import {IWormhole} from "wormhole-solidity-sdk/interfaces/IWormhole.sol";

contract EnvParamsInitialize is Script {
    function run() public payable {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address nttFactory = vm.envAddress("NTT_FACTORY");

        NttFactory factory = NttFactory(nttFactory);

        address wormholeCoreBridge = vm.envAddress("WORMHOLE_CORE_BRIDGE");
        // TODO: Relayers are deprecated and will be removed once NttManager is updated
        // Using address(0) for now
        address wormholeRelayer = address(0);
        address specialRelayer = address(0);
        uint16 whChainId = IWormhole(wormholeCoreBridge).chainId();

        vm.startBroadcast(deployerPrivateKey);

        factory.initializeWormholeConfig(wormholeCoreBridge, wormholeRelayer, specialRelayer, whChainId);

        vm.stopBroadcast();

        console2.log("envParams initialized for: ", address(factory));
    }
}
