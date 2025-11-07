// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {Script, console2} from "forge-std/Script.sol";
import {NttFactory} from "../src/NttFactory.sol";
import {INttFactory} from "../src/interfaces/INttFactory.sol";
import {PeersManager} from "../src/PeersManager.sol";
import {IManagerBase} from "native-token-transfers/interfaces/IManagerBase.sol";
import {INttManager} from "native-token-transfers/interfaces/INttManager.sol";
import {IWormhole} from "wormhole-solidity-sdk/interfaces/IWormhole.sol";

contract TestNttDeployment is Script {
    function run() public payable {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Use the deployed factory on Sei testnet
        address factoryAddress = vm.envAddress("NTT_FACTORY");
        NttFactory factory = NttFactory(factoryAddress);

        // Token to use in locking mode (18 decimals)
        address existingToken = 0xA9d21ed8260DE08fF39DC5e7B65806d4e1CB817B;

        console2.log("=== Test NTT Deployment Configuration ===");
        console2.log("Factory:", factoryAddress);
        console2.log("Deployer:", deployer);
        console2.log("Existing Token (LOCKING mode):", existingToken);
        console2.log("==========================================");

        // Calculate deployment fee
        // For testing, we'll deploy without peers first (just the NTT manager and transceiver)
        uint256 numberOfPeers = 0;
        uint256 fee = factory.calculateFee(numberOfPeers);
        console2.log("Required fee:", fee);

        // Prepare deployment parameters
        INttFactory.TokenParams memory tokenParams = INttFactory.TokenParams({
            name: "Test Token",
            symbol: "TEST",
            existingAddress: existingToken,
            initialSupply: 0 // Not used in LOCKING mode
        });
        
        // Empty peer params for initial deployment
        PeersManager.PeerParams[] memory peerParams = new PeersManager.PeerParams[](0);

        // External salt to ensure unique deployment
        string memory externalSalt = string(abi.encodePacked("test-", vm.toString(block.timestamp)));
        
        // Outbound limit must fit in uint64 (max ~18.4 * 10^18)
        // For a token with 18 decimals, this is reasonable
        uint256 outboundLimit = 1000000 * 10**18; // 1M tokens

        vm.startBroadcast(deployerPrivateKey);

        console2.log("Deploying NTT in LOCKING mode...");
        
        (
            address token,
            address nttManager,
            address transceiver,
            address proxyOwner
        ) = factory.deployNtt{value: fee}(
            IManagerBase.Mode.LOCKING,
            tokenParams,
            externalSalt,
            outboundLimit,
            peerParams,
            false // Don't create token, use existing one
        );

        console2.log("");
        console2.log("=== Deployment Results ===");
        console2.log("Token Address:", token);
        console2.log("NTT Manager:", nttManager);
        console2.log("Transceiver:", transceiver);
        console2.log("Proxy Owner:", proxyOwner);
        console2.log("==========================");

        // Verify token address matches the input
        require(token == existingToken, "Token address mismatch in LOCKING mode");
        console2.log("[OK] Token address verified (LOCKING mode)");

        // Verify NTT Manager is properly configured
        INttManager manager = INttManager(nttManager);
        require(address(manager.token()) == existingToken, "Manager token mismatch");
        console2.log("[OK] Manager token configuration verified");

        require(uint8(manager.getMode()) == uint8(IManagerBase.Mode.LOCKING), "Manager mode mismatch");
        console2.log("[OK] Manager mode verified (LOCKING)");

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== Test Deployment Successful ===");
        console2.log("Factory is working correctly!");
        console2.log("===================================");
    }
}
