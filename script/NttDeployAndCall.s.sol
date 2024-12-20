// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {NttFactory} from "../src/NttFactory.sol";
import {PeersLibrary} from "../src/PeersLibrary.sol";

import {IManagerBase} from "native-token-transfers/interfaces/IManagerBase.sol";
import {INttFactory} from "../src/interfaces/INttFactory.sol";

contract NttDeployAndCall is Script {
    function run(uint16 whHomeChainId) public payable {
        deploy(whHomeChainId);
    }

    function deploy(uint16 peerChainId) internal {
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
        factoryBaseSepolia.deployNtt(IManagerBase.Mode.BURNING, tokenParams, "salt", initialSupply, peerParams);
        vm.stopBroadcast();
        console2.log("Base Sepolia deployment completed.");
    }
}
