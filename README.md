# NTT Factory

## Creating New NTT Tokens

To create a new token, call `deployNtt` with the following parameters:

- `mode`: BURNING or LOCKING
- `tokenParams` (name, symbol, initialSupply, existingAddress): When using `LOCKING` mode, `existingAddress` specifies the token to lock. Otherwise, the remaining parameters are used for token creation.
- `externalSalt`: Random string provided for salt randomization
- `outboundLimit`: The maximum outbound transfer limit
- `envParams`: Contains Relayer, special relayer, and Wormhole bridge addresses for the chain in use
- `peerParams`: Array containing decimals, inboundLimit, and chain data. The address is expected to be consistent across chains
- `nttManagerBytecode`: Bytecode used for the implementation deployment of NttManager
- `nttTransceiverBytecode`: Bytecode used for the implementation deployment of WormholeTransceiver

## Proxies

The Manager and Transceiver are deployed behind a proxy. The deterministic address used is that of the proxy, not the implementation. We utilize OpenZeppelin's `ERC1967Proxy` for this purpose.

## Ownership

A contract is provided to relay calls to `NttManager` and `WormholeTransceiver`. This contract also serves as a mechanism to grant ownership rights for batch-setting new peers.

New tokens designate the sender as the owner, and the initialSupply is minted to that address.

## Deterministic Addresses and Salts

To maintain consistent addresses across EVM chains and establish peers before deployment, we employ `CREATE3`. This method uses a salt based on the NTT token parameters, factory version, and an `externalSalt` string.

### Tokens

For new tokens, the address depends on:

1. VERSION
2. msg.sender
3. tokenName
4. tokenSymbol
5. externalSalt

The externalSalt is necessary to allow deployment of multiple tokens with identical names and symbols.

### Manager

We omit the token address here since multiple NTT tokens may exist for the same ERC20. Additionally, in hub-and-spoke architectures, the address on the home chain will differ from those on other chains.

1. VERSION
2. "MANAGER"
3. msg.sender
4. externalSalt

### Transceiver

1. VERSION
2. "TRANSCEIVER"
3. msg.sender
4. nttManager

The `nttManager` address is incorporated into the salt calculation.
