# NTT Factory

To deploy a new factory using the script `NttFactory.s.sol`, CREATE2 is used to maintain the same address across chains for a given bytecode and deployer. The deployer is passed as parameter to avoid conflicts with the `CREATE2` usage. Other parameters are initialized later to avoid problems with block gas limit and different bytecodes for different chains.

A new factory requires calling before trying to deploy and NTT in case of not using `NttFactory.s.sol`.

1. initializeManagerBytecode
2. initializeTransceiverBytecode
3. initializeWormholeConfig (wormhole core bridge and the wormhole chain in use)

**Note**: The relayer and special relayer parameters are deprecated and should be set to `address(0)`. They are maintained for backward compatibility but will be removed once NttManager is updated.

For multiple deployments, the `deploy.sh` bash script is provided that takes a file `addresses.csv` with the required parameters and deploy on each chain. Each chain must be configured on `foundry.toml` beforehand.

## Creating New NTT Tokens

To create a new token, call `deployNtt` with the following parameters:

- `mode`: BURNING or LOCKING
- `tokenParams` (name, symbol, initialSupply, existingAddress): When using `LOCKING` mode, `existingAddress` specifies the token to lock. Otherwise, the remaining parameters are used for token creation.
- `externalSalt`: Random string provided for salt randomization
- `outboundLimit`: The maximum outbound transfer limit
- `peerParams`: Array containing decimals, inboundLimit, and chain data. The address is expected to be consistent across chains

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

## Future work

### zkSync

At the time of writing Wormhole does not support zkSync Era so this is informational in case it is supported in the future.

The contract uses both Create2 (from OpenZeppelin) and CREATE3 (from Solmate) for deterministic contract deployment. However, these deployment methods will not work on zkSync Era because according to the docs the zkSync compiler requires all contract bytecode to be known at compilation time to generate validity proofs. Using dynamic deployment methods like Create2 and Create3 where the bytecode is determined at runtime is not supported.

If zkSync Era compatibility is required, consider:

- Using standard new deployments instead of Create2/CREATE3
- Implementing an alternative deployment strategy specific to zkSync Era
- Using zkSync's native factory contracts and deployment methods
