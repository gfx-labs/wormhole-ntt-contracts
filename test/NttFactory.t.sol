// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {NttFactory} from "../src/NttFactory.sol";
import {PeerToken} from "../vendor/tokens/PeerToken.sol";
import {NttManager} from "../vendor/NttManager/NttManager.sol";
import {WormholeTransceiver} from "../vendor/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";
import {IManagerBase} from "../vendor/interfaces/IManagerBase.sol";
import {Create2} from "lib/openzeppelin-contracts/contracts/utils/Create2.sol";
import {CREATE3} from "solmate/utils/CREATE3.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockWormhole {
    uint16 private _chainId;

    constructor(uint16 chainId_) {
        _chainId = chainId_;
    }

    function chainId() external view returns (uint16) {
        return _chainId;
    }

    function publishMessage(uint32 nonce, bytes memory payload, uint8 consistencyLevel)
        external
        payable
        returns (uint64 sequence)
    {
        sequence = 1;
    }
}

contract MockERC20 is ERC20 {
    uint8 private _decimals;

    constructor(string memory name, string memory symbol, uint8 decimalsArg) ERC20(name, symbol) {
        _decimals = decimalsArg;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}

contract NttFactoryTest is Test {
    NttFactory public factory;
    MockWormhole public wormhole;

    bytes32 constant VERSION = bytes32("v1.0.0");
    address constant OWNER = address(0x1);
    uint16 constant CHAIN_ID = 1;

    // Test parameters
    string constant TOKEN_NAME = "Test Token";
    string constant TOKEN_SYMBOL = "TEST";
    string constant EXTERNAL_SALT = "external salt";
    uint256 constant INITIAL_SUPPLY = 1000000 * 1e18;
    uint256 constant OUTBOUND_LIMIT = 1000 * 1e18;

    MockERC20 public existing_token;

    function setUp() public {
        // Deploy mock wormhole
        wormhole = new MockWormhole(CHAIN_ID);

        // Deploy factory
        factory = new NttFactory(VERSION);

        existing_token = new MockERC20(TOKEN_NAME, TOKEN_SYMBOL, 18);

        // Setup owner
        vm.startPrank(OWNER);
    }

    function test_DeployNtt_LOCKINGMode() public {
        // Setup environment parameters
        NttFactory.EnvParams memory envParams = NttFactory.EnvParams({
            wormholeCoreBridge: address(wormhole),
            wormholeRelayerAddr: address(0x2),
            specialRelayerAddr: address(0x3)
        });

        // Setup peer parameters
        NttFactory.PeerParams[] memory peerParams = new NttFactory.PeerParams[](1);
        peerParams[0] = NttFactory.PeerParams({peerChainId: 2, decimals: 18, inboundLimit: OUTBOUND_LIMIT});

        // Mock bytecode for manager and transceiver
        bytes memory mockManagerBytecode = type(NttManager).creationCode;
        bytes memory mockTransceiverBytecode = type(WormholeTransceiver).creationCode;

        // Deploy NTT system
        (address token, address nttManager, address transceiver) = factory.deployNtt(
            IManagerBase.Mode.BURNING,
            TOKEN_NAME,
            TOKEN_SYMBOL,
            address(0), // Not used in BURNING mode
            EXTERNAL_SALT,
            INITIAL_SUPPLY,
            OUTBOUND_LIMIT,
            envParams,
            peerParams,
            mockManagerBytecode,
            mockTransceiverBytecode
        );

        // Verify token deployment
        PeerToken deployedToken = PeerToken(token);
        assertEq(deployedToken.name(), TOKEN_NAME);
        assertEq(deployedToken.symbol(), TOKEN_SYMBOL);
        assertEq(deployedToken.balanceOf(OWNER), INITIAL_SUPPLY);
        assertEq(deployedToken.minter(), nttManager);
        assertEq(deployedToken.owner(), OWNER);

        // Verify manager deployment
        NttManager deployedManager = NttManager(nttManager);
        assertEq(address(deployedManager.token()), token);
        // assertEq(address(deployedManager..transceiver()), transceiver);
        assertEq(deployedManager.owner(), OWNER);
        // assertEq(deployedManager.outboundLimit(), OUTBOUND_LIMIT);

        // Verify transceiver deployment
        WormholeTransceiver deployedTransceiver = WormholeTransceiver(transceiver);
        assertEq(address(deployedTransceiver.nttManager()), nttManager);
        assertTrue(deployedTransceiver.isWormholeEvmChain(2));
        assertTrue(deployedTransceiver.isWormholeRelayingEnabled(2));
    }

    function test_DeployNtt_LockingMode() public {
        // First deploy a token separately
        PeerToken existingToken = new PeerToken(TOKEN_NAME, TOKEN_SYMBOL, OWNER, OWNER);

        // Setup environment parameters
        NttFactory.EnvParams memory envParams = NttFactory.EnvParams({
            wormholeCoreBridge: address(wormhole),
            wormholeRelayerAddr: address(0x2),
            specialRelayerAddr: address(0x3)
        });

        // Setup peer parameters
        NttFactory.PeerParams[] memory peerParams = new NttFactory.PeerParams[](1);
        peerParams[0] = NttFactory.PeerParams({peerChainId: 2, decimals: 18, inboundLimit: OUTBOUND_LIMIT});

        // Mock bytecode for manager and transceiver
        bytes memory mockManagerBytecode = type(NttManager).creationCode;
        bytes memory mockTransceiverBytecode = type(WormholeTransceiver).creationCode;

        // Deploy NTT system
        (address token, address nttManager, address transceiver) = factory.deployNtt(
            IManagerBase.Mode.LOCKING,
            TOKEN_NAME,
            TOKEN_SYMBOL,
            address(existingToken),
            EXTERNAL_SALT,
            INITIAL_SUPPLY, // Not used in LOCKING mode
            OUTBOUND_LIMIT,
            envParams,
            peerParams,
            mockManagerBytecode,
            mockTransceiverBytecode
        );

        // Verify token is the existing one
        assertEq(token, address(existingToken));

        // Verify manager deployment
        NttManager deployedManager = NttManager(nttManager);
        assertEq(address(deployedManager.token()), token);
        //assertEq(address(deployedManager.transceiver()), transceiver);
        assertEq(deployedManager.owner(), OWNER);
        //assertEq(deployedManager.outboundLimit(), OUTBOUND_LIMIT);

        // Verify transceiver deployment
        WormholeTransceiver deployedTransceiver = WormholeTransceiver(transceiver);
        assertEq(address(deployedTransceiver.nttManager()), nttManager);
        assertTrue(deployedTransceiver.isWormholeEvmChain(2));
        assertTrue(deployedTransceiver.isWormholeRelayingEnabled(2));
    }

    function test_RevertInvalidParameters() public {
        NttFactory.EnvParams memory envParams = NttFactory.EnvParams({
            wormholeCoreBridge: address(wormhole),
            wormholeRelayerAddr: address(0x2),
            specialRelayerAddr: address(0x3)
        });

        NttFactory.PeerParams[] memory peerParams = new NttFactory.PeerParams[](1);
        bytes memory mockBytecode = "";

        // Test empty token name
        vm.expectRevert(NttFactory.InvalidParameters.selector);
        factory.deployNtt(
            IManagerBase.Mode.BURNING,
            "",
            TOKEN_SYMBOL,
            address(0),
            EXTERNAL_SALT,
            INITIAL_SUPPLY,
            OUTBOUND_LIMIT,
            envParams,
            peerParams,
            mockBytecode,
            mockBytecode
        );

        // Test empty token symbol
        vm.expectRevert(NttFactory.InvalidParameters.selector);
        factory.deployNtt(
            IManagerBase.Mode.BURNING,
            TOKEN_NAME,
            "",
            address(0),
            EXTERNAL_SALT,
            INITIAL_SUPPLY,
            OUTBOUND_LIMIT,
            envParams,
            peerParams,
            mockBytecode,
            mockBytecode
        );
    }

    function test_DeploymentDeterminismBurning() public {
        // TODO Refactor or use assume/bound
        IManagerBase.Mode mode = IManagerBase.Mode.BURNING;

        // Setup parameters
        NttFactory.EnvParams memory envParams = NttFactory.EnvParams({
            wormholeCoreBridge: address(wormhole),
            wormholeRelayerAddr: address(0x2),
            specialRelayerAddr: address(0x3)
        });

        NttFactory.PeerParams[] memory peerParams = new NttFactory.PeerParams[](1);
        peerParams[0] = NttFactory.PeerParams({peerChainId: 2, decimals: 18, inboundLimit: OUTBOUND_LIMIT});

        bytes memory mockManagerBytecode = type(NttManager).creationCode;
        bytes memory mockTransceiverBytecode = type(WormholeTransceiver).creationCode;

        // Deploy twice with same parameters
        (address token1, address manager1, address transceiver1) = factory.deployNtt(
            mode,
            TOKEN_NAME,
            TOKEN_SYMBOL,
            address(0),
            EXTERNAL_SALT,
            INITIAL_SUPPLY,
            OUTBOUND_LIMIT,
            envParams,
            peerParams,
            mockManagerBytecode,
            mockTransceiverBytecode
        );

        vm.expectRevert(); // Should revert on second deployment with same parameters
        factory.deployNtt(
            mode,
            TOKEN_NAME,
            TOKEN_SYMBOL,
            address(0),
            EXTERNAL_SALT,
            INITIAL_SUPPLY,
            OUTBOUND_LIMIT,
            envParams,
            peerParams,
            mockManagerBytecode,
            mockTransceiverBytecode
        );

        // should not fail with a different external salt
        (address token2, address manager2, address transceiver2) = factory.deployNtt(
            mode,
            TOKEN_NAME,
            TOKEN_SYMBOL,
            address(0),
            "DIFFERENT_SALT",
            INITIAL_SUPPLY,
            OUTBOUND_LIMIT,
            envParams,
            peerParams,
            mockManagerBytecode,
            mockTransceiverBytecode
        );

        // Verify first deployment was successful
        assertTrue(token1 != address(0));
        assertTrue(manager1 != address(0));
        assertTrue(transceiver1 != address(0));

        // Verify second deployment was successful
        assertTrue(token2 != address(0));
        assertTrue(manager2 != address(0));
        assertTrue(transceiver2 != address(0));
    }

    function test_DeploymentDeterminismLocking() public {
        // TODO Refactor or use assume/bound
        IManagerBase.Mode mode = IManagerBase.Mode.LOCKING;

        // Setup parameters
        NttFactory.EnvParams memory envParams = NttFactory.EnvParams({
            wormholeCoreBridge: address(wormhole),
            wormholeRelayerAddr: address(0x2),
            specialRelayerAddr: address(0x3)
        });

        NttFactory.PeerParams[] memory peerParams = new NttFactory.PeerParams[](1);
        peerParams[0] = NttFactory.PeerParams({peerChainId: 2, decimals: 18, inboundLimit: OUTBOUND_LIMIT});

        bytes memory mockManagerBytecode = type(NttManager).creationCode;
        bytes memory mockTransceiverBytecode = type(WormholeTransceiver).creationCode;

        // Deploy twice with same parameters
        (address token1, address manager1, address transceiver1) = factory.deployNtt(
            mode,
            TOKEN_NAME,
            TOKEN_SYMBOL,
            address(existing_token),
            EXTERNAL_SALT,
            INITIAL_SUPPLY,
            OUTBOUND_LIMIT,
            envParams,
            peerParams,
            mockManagerBytecode,
            mockTransceiverBytecode
        );

        vm.expectRevert(); // Should revert on second deployment with same parameters
        factory.deployNtt(
            mode,
            TOKEN_NAME,
            TOKEN_SYMBOL,
            address(existing_token),
            EXTERNAL_SALT,
            INITIAL_SUPPLY,
            OUTBOUND_LIMIT,
            envParams,
            peerParams,
            mockManagerBytecode,
            mockTransceiverBytecode
        );

        // should not fail with a different external salt
        (address token2, address manager2, address transceiver2) = factory.deployNtt(
            mode,
            TOKEN_NAME,
            TOKEN_SYMBOL,
            address(existing_token),
            "DIFFERENT_SALT",
            INITIAL_SUPPLY,
            OUTBOUND_LIMIT,
            envParams,
            peerParams,
            mockManagerBytecode,
            mockTransceiverBytecode
        );

        // Verify first deployment was successful
        assertTrue(token1 != address(0));
        assertTrue(manager1 != address(0));
        assertTrue(transceiver1 != address(0));

        // Verify second deployment was successful
        assertTrue(token2 != address(0));
        assertTrue(manager2 != address(0));
        assertTrue(transceiver2 != address(0));
    }
}
