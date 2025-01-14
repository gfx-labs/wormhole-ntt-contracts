// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {Script, console2} from "forge-std/Script.sol";
import {NttFactory} from "../src/NttFactory.sol";
import {IWormhole} from "wormhole-solidity-sdk/interfaces/IWormhole.sol";
import {WormholeTransceiver} from "native-token-transfers/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

contract EnvParamsInitialize is Script {
    function run() public payable {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address nttFactory = vm.envAddress("NTT_FACTORY");

        NttFactory factory = NttFactory(nttFactory);

        vm.startBroadcast(deployerPrivateKey);

        factory.initializeTransceiverBytecode(type(WormholeTransceiver).creationCode);

        vm.stopBroadcast();

        console2.log("transceiverBytecode initialized for: ", address(factory));
    }
}
