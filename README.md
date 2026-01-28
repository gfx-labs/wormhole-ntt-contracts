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

-   `mode`: BURNING or LOCKING
-   `tokenParams` (name, symbol, initialSupply, existingAddress): When using `LOCKING` mode, `existingAddress` specifies the token to lock. Otherwise, the remaining parameters are used for token creation.
-   `externalSalt`: Random string provided for salt randomization
-   `outboundLimit`: The maximum outbound transfer limit
-   `peerParams`: Array containing decimals, inboundLimit, and chain data. The address is expected to be consistent across chains

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

-   Using standard new deployments instead of Create2/CREATE3
-   Implementing an alternative deployment strategy specific to zkSync Era
-   Using zkSync's native factory contracts and deployment methods

## Mainnet Deployments

EVM Factory Address `0x9e2B47ACaf61Ad2fF26B2608b9D915325c484fF1`
EVM Transceiver Address `0x5045964706b08b8258f0e1258f30a633360e2387`

- Mainnet: https://etherscan.io/address/0x9e2B47ACaf61Ad2fF26B2608b9D915325c484fF1
- Optimism: https://optimistic.etherscan.io/address/0x9e2B47ACaf61Ad2fF26B2608b9D915325c484fF1
- Arbitrum: https://arbiscan.io/address/0x9e2B47ACaf61Ad2fF26B2608b9D915325c484fF1
- Base: https://basescan.org/address/0x9e2B47ACaf61Ad2fF26B2608b9D915325c484fF1
- Polygon: https://polygonscan.com/address/0x9e2b47acaf61ad2ff26b2608b9d915325c484ff1
- Binance Smart Chain: https://bscscan.com/address/0x9e2B47ACaf61Ad2fF26B2608b9D915325c484fF1
- Berachain: https://berascan.com/address/0x9e2B47ACaf61Ad2fF26B2608b9D915325c484fF1
- ~~Mantle [deprecated by WH]: https://mantlescan.xyz/address/0x9e2B47ACaf61Ad2fF26B2608b9D915325c484fF1~~
- Unichain: https://unichain.blockscout.com/address/0x9e2B47ACaf61Ad2fF26B2608b9D915325c484fF1
- Worldchain: https://worldscan.org/address/0x9e2B47ACaf61Ad2fF26B2608b9D915325c484fF1
- Celo: https://celoscan.io/address/0x9e2B47ACaf61Ad2fF26B2608b9D915325c484fF1
- Ink: https://explorer.inkonchain.com/address/0x9e2B47ACaf61Ad2fF26B2608b9D915325c484fF1
- Scroll: https://scrollscan.com/address/0x9e2B47ACaf61Ad2fF26B2608b9D915325c484fF1
- Avalanche: https://snowtrace.io/address/0x9e2B47ACaf61Ad2fF26B2608b9D915325c484fF1
- HyperEVM: https://hyperevmscan.io/address/0x9e2b47acaf61ad2ff26b2608b9d915325c484ff1#code
- XRPL EVM: https://explorer.xrplevm.org/address/0xCf918C361446538642c233315167B498A59EeE87 (Factory: `0xCf918C361446538642c233315167B498A59EeE87`)

## Testnet Deployments

- Sepolia: [https://sepolia.etherscan.io/address/0x9e2B47ACaf61Ad2fF26B2608b9D915325c484fF1](https://sepolia.etherscan.io/address/0x9e2B47ACaf61Ad2fF26B2608b9D915325c484fF1#code)
- Base Sepolia: https://sepolia.basescan.org/address/0x9e2B47ACaf61Ad2fF26B2608b9D915325c484fF1
- Arbitrum Sepolia: https://sepolia.arbiscan.io/address/0x9e2B47ACaf61Ad2fF26B2608b9D915325c484fF1
- Optimism Sepolia: https://sepolia-optimism.etherscan.io/address/0x9e2B47ACaf61Ad2fF26B2608b9D915325c484fF1
- Unichain Sepolia: https://unichain-sepolia.blockscout.com/address/0x9e2B47ACaf61Ad2fF26B2608b9D915325c484fF1
- Ink Sepolia: [https://explorer-sepolia.inkonchain.com/address/0x8C0Df866a9b3a260eF3abe4AbAC203498415e214](https://explorer-sepolia.inkonchain.com/address/0x8C0Df866a9b3a260eF3abe4AbAC203498415e214?tab=write_contract)
- XRPL EVM Testnet: https://explorer.testnet.xrplevm.org/address/0xCf918C361446538642c233315167B498A59EeE87 (Factory: `0xCf918C361446538642c233315167B498A59EeE87`)

## NTT Contract Verification Guide

### Quick Start

```bash
git clone https://github.com/gfx-labs/wormhole-ntt-contracts.git
cd wormhole-ntt-contracts
forge install
forge build --force --optimize --optimizer-runs 200
```

### Verify NttManager

```bash
forge verify-contract <IMPLEMENTATION_ADDRESS> \
    lib/native-token-transfers/evm/src/NttManager/NttManager.sol:NttManager \
    --verifier etherscan \
    --verifier-url "https://api.etherscan.io/v2/api?chainid=<EVM_CHAIN_ID>" \
    --etherscan-api-key <API_KEY> \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address,uint8,uint16,uint64,bool)" \
        <TOKEN_ADDRESS> \
        <MODE> \
        <WORMHOLE_CHAIN_ID> \
        86400 \
        false)
```

### Verify WormholeTransceiver

```bash
forge verify-contract <IMPLEMENTATION_ADDRESS> \
    lib/native-token-transfers/evm/src/Transceiver/WormholeTransceiver/WormholeTransceiver.sol:WormholeTransceiver \
    --verifier etherscan \
    --verifier-url "https://api.etherscan.io/v2/api?chainid=<EVM_CHAIN_ID>" \
    --etherscan-api-key <API_KEY> \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address,address,address,address,uint8,uint256)" \
        <NTT_MANAGER_PROXY> \
        <WORMHOLE_CORE_BRIDGE> \
        <WORMHOLE_RELAYER> \
        <SPECIAL_RELAYER> \
        202 \
        500000)
```

### Notes

- `MODE`: 0 = LOCKING (source chain), 1 = BURNING (peer chain)
- Use Wormhole chain ID, not EVM chain ID, for the constructor
- The `--optimize --optimizer-runs 200` flag is required when building
