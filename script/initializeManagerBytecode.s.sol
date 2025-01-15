// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {Script, console2} from "forge-std/Script.sol";
import {NttFactory} from "../src/NttFactory.sol";
import {IWormhole} from "wormhole-solidity-sdk/interfaces/IWormhole.sol";
import {NttManager} from "native-token-transfers/NttManager/NttManager.sol";

contract EnvParamsInitialize is Script {
    function run() public payable {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address nttFactory = vm.envAddress("NTT_FACTORY");

        NttFactory factory = NttFactory(nttFactory);

        vm.startBroadcast(deployerPrivateKey);

        factory.initializeManagerBytecode(type(NttManager).creationCode);

        vm.stopBroadcast();

        console2.log("managerBytecode initialized for: ", address(factory));
    }
}
