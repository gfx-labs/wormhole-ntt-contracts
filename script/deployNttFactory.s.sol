// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {Script, console2} from "forge-std/Script.sol";
import {NttFactory} from "../src/NttFactory.sol";
import {IWormhole} from "wormhole-solidity-sdk/interfaces/IWormhole.sol";
import {NttManager} from "native-token-transfers/NttManager/NttManager.sol";
import {WormholeTransceiver} from "native-token-transfers/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

contract NttFactoryDeploy is Script {
    function run() public payable {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        bytes32 salt = keccak256(abi.encodePacked(deployer));

        address wormholeCoreBridge = vm.envAddress("WORMHOLE_CORE_BRIDGE");
        address wormholeRelayer = vm.envAddress("WORMHOLE_RELAYER");
        address specialRelayer = vm.envAddress("SPECIAL_RELAYER");
        bytes32 currentVersion = bytes32(bytes(vm.envString("VERSION")));

        uint16 whChainId = IWormhole(wormholeCoreBridge).chainId();

        vm.startBroadcast(deployerPrivateKey);
        NttFactory factory = new NttFactory{salt: salt}(deployer, currentVersion);

        factory.initializeManagerBytecode(type(NttManager).creationCode);
        factory.initializeTransceiverBytecode(type(WormholeTransceiver).creationCode);
        factory.initializeWormholeConfig(wormholeCoreBridge, wormholeRelayer, specialRelayer, whChainId);

        vm.stopBroadcast();

        console2.log("Factory deployed to:", address(factory));
    }
}
