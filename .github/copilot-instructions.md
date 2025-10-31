# Wormhole NTT Factory - AI Coding Agent Instructions

## Project Overview

This is a **Foundry-based Solidity project** that implements a factory contract for deploying cross-chain Native Token Transfers (NTT) using Wormhole's protocol. The factory uses advanced deterministic deployment strategies (CREATE2, CREATE3) to ensure consistent addresses across EVM chains.

**Core Purpose**: Enable seamless cross-chain token transfers by deploying NTT infrastructure that can operate in two modes:

-   **BURNING mode**: Deploy new tokens on all chains, burn/mint for transfers
-   **LOCKING mode**: Use existing tokens, lock/unlock for transfers (critical for established tokens on primary chains)

**Key Design Constraint**: The factory supports existing token compatibility without requiring peer token deployments on secondary chains. Primary chain token deployments have become optional in recent versions, allowing maximum flexibility for integrating with established token ecosystems.

## Architecture & Key Components

### Core Contracts (`src/`)

-   **`NttFactory.sol`**: Main factory deploying NTT tokens, managers, transceivers, and proxy owners
    -   Uses SSTORE2 to store large bytecodes (manager/transceiver) on-chain to avoid block gas limits
    -   Deploys components deterministically: CREATE3 for proxies/tokens, CREATE2 for implementations
    -   Initialized in 3 steps: `initializeManagerBytecode()`, `initializeTransceiverBytecode()`, `initializeWormholeConfig()`
-   **`NttProxyOwner.sol`**: Owner contract for deployed NTT managers/transceivers
    -   Provides multicall functionality (`executeMany`) for batch operations
    -   Based on Multicall3 pattern
-   **`PeersManager.sol`**: Abstract contract with peer configuration helpers

    -   Configures cross-chain peers for both managers and transceivers
    -   Normalizes addresses to bytes32 format for Wormhole

-   **`tokens/PeerToken.sol`**: ERC20Burnable token with minter role
    -   Always deployed with 18 decimals regardless of peer chain decimals
    -   Initial minter is factory, transferred to NttManager after deployment

### Deterministic Address Strategy

**Critical for cross-chain deployments** - addresses must be predictable before deployment:

1. **Token salt**: `keccak256(version, msg.sender, name, symbol, externalSalt)`
2. **Manager salt**: `keccak256(version, "MANAGER", msg.sender, externalSalt)`
    - Omits token address to support multiple NTTs for same ERC20
3. **Transceiver salt**: `keccak256(version, "TRANSCEIVER", msg.sender, nttManager)`
4. **ProxyOwner salt**: `keccak256(nttManager, factory, externalSalt, owner)`

### Deployment Flow

1. Deploy factory via `script/deployNttFactory.s.sol` using CREATE2 (same address per deployer)
2. Factory initialization (3 separate calls required):
    ```solidity
    factory.initializeManagerBytecode(type(NttManager).creationCode);
    factory.initializeTransceiverBytecode(type(WormholeTransceiver).creationCode);
    // Note: relayer parameters are deprecated, use address(0)
    factory.initializeWormholeConfig(coreBridge, address(0), address(0), chainId);
    ```
3. Deploy tokens via `factory.deployNtt()` - creates token (optional), manager proxy, transceiver proxy, and owner

### Operating Modes

-   **BURNING**: New token created, NTT burns/mints tokens (requires minter role)

    -   Factory creates `PeerToken` with 18 decimals (always, regardless of peer decimals)
    -   NttManager receives minter role after deployment
    -   Token owner remains `msg.sender` for governance
    -   Ideal for new token launches across multiple chains

-   **LOCKING**: Existing ERC20 token, NTT locks/unlocks tokens
    -   Critical for established tokens on primary chains (e.g., USDC on Ethereum)
    -   No peer token deployment required on secondary chains
    -   Token contract must expose standard ERC20 interface
    -   Factory doesn't modify existing token ownership or permissions
    -   Primary chain deployments are optional - can start with secondary chains only

## Development Workflows

### Build & Test

```bash
# Build (requires viaIR optimization)
forge build --via-ir

# Test
forge test

# Test with verbosity
forge test -vvvv

# Clean
npm run clean  # or: rm -rf cache out && forge clean
```

### Multi-Chain Deployment

Use `deploy.sh` for batch deployments across chains configured in `foundry.toml`:

```bash
# Requires: .env with VERSION, addresses.csv with chain configs
export VERSION="0.0.1"
./deploy.sh
```

Format of `addresses.csv`: `network,coreBridge,relayer,specialRelayer`
**Note**: The `relayer` and `specialRelayer` columns are deprecated but kept for backward compatibility. They are no longer used in deployments (set to address(0)).

### Key Environment Variables

-   `DEPLOYER_PRIVATE_KEY`: Deployer private key for transactions
-   `VERSION`: Factory version (used in salts for deterministic addresses)
-   `NTT_FACTORY`: Factory address for token deployments
-   `WORMHOLE_CORE_BRIDGE`: Wormhole core bridge address per chain
-   `API_KEY_ALCHEMY`: For RPC endpoints
-   Chain-specific Etherscan keys: `ARBITRUM_ETHERSCAN_KEY`, `BASESEPOLIA_ETHERSCAN_KEY`, etc.
-   **Deprecated**: `WORMHOLE_RELAYER`, `SPECIAL_RELAYER` (no longer used, set to address(0))

### Foundry Configuration

-   **Solidity**: 0.8.22 (strict version)
-   **viaIR**: ALWAYS required (critical for optimization)
-   **CBOR metadata**: Enabled for bytecode verification

## Project-Specific Patterns

### 1. SSTORE2 Bytecode Storage

Large bytecodes (NttManager ~20KB) are stored using SSTORE2 to avoid CREATE2 size limits:

```solidity
// Split manager bytecode in half for storage
uint256 mid = managerBytecode.length / 2;
nttManagerBytecode1 = SSTORE2.write(managerBytecode[0:mid]);
nttManagerBytecode2 = SSTORE2.write(managerBytecode[mid:]);

// Reconstruct on deployment
bytes memory bytecode = abi.encodePacked(
    SSTORE2.read(nttManagerBytecode1),
    SSTORE2.read(nttManagerBytecode2),
    abi.encode(constructorArgs...)
);
```

### 2. Proxy Pattern

Uses OpenZeppelin's `ERC1967Proxy` for upgradeability:

-   Implementations deployed with CREATE2
-   Proxies deployed with CREATE3 (deterministic across chains)
-   Implementation address varies, proxy address stays constant

### 3. Wormhole Fee Calculation

Always calculate required fees before calling `deployNtt()`:

```solidity
uint256 fee = factory.calculateFee(numberOfPeers);
factory.deployNtt{value: fee}(...);
```

Fee = `(1 + numberOfPeers) * wormholeCoreBridge.messageFee()`

### 4. Testing with Mocks

Tests use `MockWormhole` and `MockERC20` to simulate cross-chain behavior without actual Wormhole infrastructure.

## Dependencies & Imports

Key dependencies (via git submodules in `lib/`):

-   **`native-token-transfers/`**: Wormhole's canonical NTT implementation
    -   Provides `NttManager`, `WormholeTransceiver`, and core interfaces
    -   This factory acts as a deployment wrapper around these battle-tested contracts
    -   Future versions will reduce/remove dependency on standard relayer and special relayer
    -   The relayer infrastructure is currently required for cross-chain messaging but may become optional
-   **`wormhole-solidity-sdk/`**: Wormhole core protocol interfaces
    -   `IWormhole` interface for core bridge messaging
    -   Chain ID mappings and message validation
-   **`openzeppelin-contracts/`**: Standard utilities
    -   `ERC1967Proxy` for upgradeable proxies
    -   `Create2` for deterministic implementation deployments
    -   `Ownable`, `ERC20`, `ERC20Burnable` base contracts
-   **`solady/`**: Gas-optimized utilities
    -   `CREATE3` for deterministic proxy deployments (address-independent)
    -   `SSTORE2` for on-chain bytecode storage (cheaper than contract deployment)

Remappings configured in `remappings.txt` - use proper import paths like:

```solidity
import {CREATE3} from "solady/utils/CREATE3.sol";
import {INttManager} from "native-token-transfers/interfaces/INttManager.sol";
```

## Important Constraints

1. **zkSync Era**: NOT supported - CREATE2/CREATE3 incompatible with zkSync's architecture
2. **Decimal Handling**: Deployed tokens always have 18 decimals; peer configuration handles cross-chain decimal differences
3. **Initialization Order**: Factory must be initialized before any token deployments (will revert otherwise)
4. **Ownership Transfer**: Factory temporarily owns tokens/managers during deployment, transfers to ProxyOwner at end
5. **externalSalt**: Required to deploy multiple tokens with identical name/symbol

## Gas Optimization Patterns & Tradeoffs

### Current Optimizations

1. **SSTORE2 for Bytecode Storage**: Stores large bytecodes (~20KB) on-chain instead of repeated deployment

    - Splits manager bytecode in half for storage efficiency
    - Reconstructs on-demand for deployment
    - Cheaper than deploying multiple times across chains

2. **Immutable Variables**: `deployer` and `version` stored as immutables (cheaper reads than storage)

    ```solidity
    address public immutable deployer;
    bytes32 public immutable version;
    ```

3. **Unchecked Arithmetic**: Used in `NttProxyOwner.executeMany()` for value accumulation

    ```solidity
    unchecked {
        valAccumulator += val;
    }
    ```

    Safe because overflow impossible before heat death of universe (10^25 Wei << 10^76)

4. **Calldata over Memory**: Function parameters use `calldata` where possible to avoid copying

    ```solidity
    function initializeManagerBytecode(bytes calldata managerBytecode)
    ```

5. **Assembly for Low-Level Operations**: Used in `NttProxyOwner` for efficient multicall error handling

6. **Packed Encoding**: `abi.encodePacked()` used for salt generation (cheaper than `abi.encode()`)
    ```solidity
    bytes32 tokenSalt = keccak256(abi.encodePacked(version, msg.sender, name, symbol, externalSalt));
    ```

### EVM Compatibility Tradeoffs (Solidity 0.8.22)

**Why We Can't Use Newer Features**:

-   Stuck on Solidity 0.8.22 for compatibility with `native-token-transfers` dependency
-   Must support all EVM chains where Wormhole operates (including older implementations)

**What We're Missing from Newer EVMs**:

1. **Transient Storage (EIP-1153)**: Not available in 0.8.22

    - Could replace temporary state during deployment with transient storage
    - Current: Factory stores addresses in storage, then transfers ownership
    - With transient: Could use `TSTORE`/`TLOAD` for temporary ownership tracking
    - **Savings**: ~20,000 gas per deployment (avoid SSTORE for temporary values)

2. **PUSH0 Opcode (0.8.20+)**: Available but not used consistently

    - Saves 2 gas per zero-value push
    - Current: Uses `PUSH1 0x00`
    - Impact: Marginal but adds up across deployments

3. **Selective Struct Packing**: Not aggressively optimized

    - Example in `PeerParams`:
        ```solidity
        struct PeerParams {
            uint16 peerChainId;  // 2 bytes
            uint8 decimals;      // 1 byte
            uint256 inboundLimit; // 32 bytes -> forces new slot
        }
        ```
    - Could pack `peerChainId` + `decimals` + `outboundLimit` (if < 2^240) into single slot
    - **Potential savings**: ~15,000 gas per peer parameter (avoid 1 SLOAD)
    - **Tradeoff**: Code complexity vs gas savings, uint256 provides overflow safety

4. **Cached Length Reads**: Not consistently applied

    - Example in `PeersManager.sol`:
        ```solidity
        for (uint256 i = 0; i < peerParams.length; i++) // reads length each iteration
        ```
    - Better: `uint256 len = peerParams.length; for (uint256 i = 0; i < len;)`
    - **Impact**: Minimal for memory arrays, but pattern inconsistency

5. **Constant vs Immutable**: Well utilized
    - `RATE_LIMIT_DURATION`, `GAS_LIMIT`, `CONSISTENCY_LEVEL` correctly use `constant`
    - `deployer`, `version` correctly use `immutable`

### Why viaIR is Critical

The `--via-ir` flag enables IR-based compilation which is **mandatory** for this project:

-   Enables aggressive inlining and cross-function optimization
-   Required to fit large bytecodes (NttManager + constructor args) within 24KB limit
-   Without it: deployment would fail on most networks
-   Tradeoff: Longer compilation time, but necessary for functionality

## File Naming Conventions

-   Contracts: PascalCase (e.g., `NttFactory.sol`)
-   Scripts: camelCase with `.s.sol` suffix (e.g., `deployNttFactory.s.sol`)
-   Tests: PascalCase with `.t.sol` suffix (e.g., `NttFactory.t.sol`)
-   Interfaces: Prefixed with `I` (e.g., `INttFactory.sol`)
