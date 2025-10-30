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
        // TODO: Relayers are deprecated and will be removed once NttManager is updated
        // Using address(0) for now
        address wormholeRelayer = address(0);
        address specialRelayer = address(0);
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
