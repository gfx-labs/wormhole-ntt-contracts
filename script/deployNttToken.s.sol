// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import { Script, console2 } from "forge-std/Script.sol";
import { NttFactory } from "../src/NttFactory.sol";
import { PeersManager } from "../src/PeersManager.sol";

import { INttFactory } from "../src/interfaces/INttFactory.sol";

import { IWormhole } from "wormhole-solidity-sdk/interfaces/IWormhole.sol";
import { IManagerBase } from "native-token-transfers/interfaces/IManagerBase.sol";

contract NttTokenDeploy is Script {
    function run() public payable {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address nttFactory = vm.envAddress("NTT_FACTORY");

        string memory tokenName = vm.envString("BURNING_TOKEN_NAME");
        string memory tokenSymbol = vm.envString("BURNING_TOKEN_SYMBOL");

        NttFactory factory = NttFactory(nttFactory);

        vm.startBroadcast(deployerPrivateKey);

        INttFactory.TokenParams memory tokenParams = INttFactory.TokenParams({
            name: tokenName,
            symbol: tokenSymbol,
            existingAddress: address(0),
            initialSupply: type(uint64).max
        });

        PeersManager.PeerParams[] memory peerParams = new PeersManager.PeerParams[](1);
        peerParams[0] = PeersManager.PeerParams({ peerChainId: 2, decimals: 18, inboundLimit: type(uint64).max });

        (address token2, , address ownerContract) = factory.deployNtt(
            IManagerBase.Mode.BURNING,
            tokenParams,
            "SALT",
            type(uint64).max
        );
        factory.deployAndInitializeTransceiver(token2, peerParams, ownerContract);

        vm.stopBroadcast();

        console2.log("deployToken on: ", address(token2));
    }
}
