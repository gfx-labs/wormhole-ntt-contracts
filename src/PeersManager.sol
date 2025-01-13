// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {IWormholeTransceiver} from "native-token-transfers/interfaces/IWormholeTransceiver.sol";
import {INttManager} from "native-token-transfers/interfaces/INttManager.sol";

abstract contract PeersManager {
    struct PeerParams {
        uint16 peerChainId;
        uint8 decimals;
        uint256 inboundLimit;
    }

    function normalizeAddress(address contractAddress) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(contractAddress)));
    }

    function configureNttTransceiver(IWormholeTransceiver transceiver, PeerParams[] memory peerParams) internal {
        bytes32 normalizedTransceiverAddress = normalizeAddress(address(transceiver));

        for (uint256 i = 0; i < peerParams.length; i++) {
            transceiver.setWormholePeer{value: msg.value}(peerParams[i].peerChainId, normalizedTransceiverAddress);
            transceiver.setIsWormholeEvmChain(peerParams[i].peerChainId, true);
            transceiver.setIsWormholeRelayingEnabled(peerParams[i].peerChainId, true);
        }
    }

    function configureNttManager(INttManager nttManager, PeerParams[] memory peerParams) internal {
        bytes32 normalizedManagerAddress = normalizeAddress(address(nttManager));

        for (uint256 i = 0; i < peerParams.length; i++) {
            nttManager.setPeer(
                peerParams[i].peerChainId, normalizedManagerAddress, peerParams[i].decimals, peerParams[i].inboundLimit
            );
        }
    }
}
