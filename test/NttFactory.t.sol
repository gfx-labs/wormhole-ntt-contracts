// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Test.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {NttManager} from "native-token-transfers/NttManager/NttManager.sol";
import {WormholeTransceiver} from "native-token-transfers/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";
import {IManagerBase} from "native-token-transfers/interfaces/IManagerBase.sol";
import {INttManager} from "native-token-transfers/interfaces/INttManager.sol";

import {NttFactory} from "../src/NttFactory.sol";
import {INttFactory} from "../src/interfaces/INttFactory.sol";
import {PeersLibrary} from "../src/PeersLibrary.sol";
import {NttOwner} from "../src/NttOwner.sol";

import {PeerToken} from "../src/tokens/PeerToken.sol";

contract MockWormhole {
    uint16 private _chainId;

    constructor(uint16 chainId_) {
        _chainId = chainId_;
    }

    function chainId() external view returns (uint16) {
        return _chainId;
    }

    function publishMessage(uint32, bytes memory, uint8) external payable returns (uint64 sequence) {
        sequence = 1;
    }
}

contract MockERC20 is ERC20, Ownable {
    uint8 private _decimals;

    constructor(string memory name, string memory symbol, uint8 decimalsArg) ERC20(name, symbol) Ownable(msg.sender) {
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

    address constant OWNER = address(0x1);
    address constant EXISTING_TOKEN_OWNER = address(0xA);
    uint16 constant CHAIN_ID = 1;

    // Test parameters
    string constant TOKEN_NAME = "Test Token";
    string constant TOKEN_SYMBOL = "TEST";
    string constant EXTERNAL_SALT = "external salt";
    uint256 constant INITIAL_SUPPLY = 1000000 * 1e18;
    uint256 constant OUTBOUND_LIMIT = 1000 * 1e18;

    MockERC20 public existing_token;

    // Mock bytecode for manager and transceiver
    bytes constant mockManagerBytecode = type(NttManager).creationCode;
    bytes constant mockTransceiverBytecode = type(WormholeTransceiver).creationCode;

    INttFactory.TokenParams public tokenParamsBurning;
    INttFactory.TokenParams public tokenParamsLocking;

    function setUp() public {
        // Deploy mock wormhole
        wormhole = new MockWormhole(CHAIN_ID);

        // Deploy factory
        vm.startPrank(OWNER);
        factory = new NttFactory(OWNER, "0.0.1");
        factory.initializeWormholeConfig(address(wormhole), address(0x2), address(0x3), wormhole.chainId());
        factory.initializeManagerBytecode(mockManagerBytecode);
        factory.initializeTransceiverBytecode(mockTransceiverBytecode);

        existing_token = new MockERC20(TOKEN_NAME, TOKEN_SYMBOL, 18);
        MockERC20(existing_token).transferOwnership(EXISTING_TOKEN_OWNER);

        tokenParamsBurning = INttFactory.TokenParams({
            name: TOKEN_NAME,
            symbol: TOKEN_SYMBOL,
            existingAddress: address(0),
            initialSupply: INITIAL_SUPPLY
        });
        tokenParamsLocking = INttFactory.TokenParams({
            name: TOKEN_NAME,
            symbol: TOKEN_SYMBOL,
            existingAddress: address(existing_token),
            initialSupply: INITIAL_SUPPLY
        });
    }

    function test_DeployNtt_BurningMode() public {
        // Setup peer parameters
        PeersLibrary.PeerParams[] memory peerParams = new PeersLibrary.PeerParams[](1);
        peerParams[0] = PeersLibrary.PeerParams({peerChainId: 2, decimals: 18, inboundLimit: OUTBOUND_LIMIT});

        // Deploy NTT system
        (address token, address nttManager, address transceiver, address ownerContract) =
            factory.deployNtt(IManagerBase.Mode.BURNING, tokenParamsBurning, EXTERNAL_SALT, OUTBOUND_LIMIT, peerParams);

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
        assertEq(deployedManager.owner(), ownerContract);
        assertEq(deployedManager.pauser(), ownerContract);
        assertEq(deployedManager.getThreshold(), 1);

        // Verify transceiver deployment
        WormholeTransceiver deployedTransceiver = WormholeTransceiver(transceiver);
        assertEq(address(deployedTransceiver.nttManager()), nttManager);
        assertEq(deployedTransceiver.owner(), ownerContract);
        assertEq(deployedTransceiver.pauser(), ownerContract);

        assertTrue(deployedTransceiver.isWormholeEvmChain(2));
        assertTrue(deployedTransceiver.isWormholeRelayingEnabled(2));
    }

    function test_DeployNtt_LockingMode() public {
        // Setup peer parameters
        PeersLibrary.PeerParams[] memory peerParams = new PeersLibrary.PeerParams[](1);
        peerParams[0] = PeersLibrary.PeerParams({peerChainId: 2, decimals: 18, inboundLimit: OUTBOUND_LIMIT});

        // Deploy NTT system
        (address token, address nttManager, address transceiver, address ownerContract) =
            factory.deployNtt(IManagerBase.Mode.LOCKING, tokenParamsLocking, EXTERNAL_SALT, OUTBOUND_LIMIT, peerParams);

        // Verify token is the existing one
        assertEq(token, address(existing_token));

        // Verify manager deployment
        NttManager deployedManager = NttManager(nttManager);
        assertEq(address(deployedManager.token()), token);
        //assertEq(address(deployedManager.transceiver()), transceiver);
        assertEq(deployedManager.owner(), ownerContract);
        //assertEq(deployedManager.outboundLimit(), OUTBOUND_LIMIT);

        // Verify transceiver deployment
        WormholeTransceiver deployedTransceiver = WormholeTransceiver(transceiver);
        assertEq(address(deployedTransceiver.nttManager()), nttManager);
        assertEq(deployedTransceiver.owner(), ownerContract);
        assertEq(deployedTransceiver.pauser(), ownerContract);
        assertEq(deployedManager.pauser(), ownerContract);
        assertEq(deployedManager.getThreshold(), 1);

        assertTrue(deployedTransceiver.isWormholeEvmChain(2));
        assertTrue(deployedTransceiver.isWormholeRelayingEnabled(2));
    }

    function test_RevertInvalidParameters() public {
        PeersLibrary.PeerParams[] memory peerParams = new PeersLibrary.PeerParams[](1);

        INttFactory.TokenParams memory tokenParamsEmptyName = INttFactory.TokenParams({
            name: "",
            symbol: TOKEN_SYMBOL,
            existingAddress: address(0),
            initialSupply: INITIAL_SUPPLY
        });

        // Test empty token name
        vm.expectRevert(INttFactory.InvalidTokenParameters.selector);
        factory.deployNtt(IManagerBase.Mode.BURNING, tokenParamsEmptyName, EXTERNAL_SALT, OUTBOUND_LIMIT, peerParams);

        // Test empty token symbol
        INttFactory.TokenParams memory tokenParamsEmptySymbol = INttFactory.TokenParams({
            name: TOKEN_NAME,
            symbol: "",
            existingAddress: address(0),
            initialSupply: INITIAL_SUPPLY
        });

        vm.expectRevert(INttFactory.InvalidTokenParameters.selector);
        factory.deployNtt(IManagerBase.Mode.BURNING, tokenParamsEmptySymbol, EXTERNAL_SALT, OUTBOUND_LIMIT, peerParams);
    }

    function test_DeploymentDeterminismBurning() public {
        IManagerBase.Mode mode = IManagerBase.Mode.BURNING;

        PeersLibrary.PeerParams[] memory peerParams = new PeersLibrary.PeerParams[](1);
        peerParams[0] = PeersLibrary.PeerParams({peerChainId: 2, decimals: 18, inboundLimit: OUTBOUND_LIMIT});

        // Deploy twice with same parameters
        (address token1, address manager1, address transceiver1,) =
            factory.deployNtt(mode, tokenParamsBurning, EXTERNAL_SALT, OUTBOUND_LIMIT, peerParams);

        vm.expectRevert(); // Should revert on second deployment with same parameters
        factory.deployNtt(mode, tokenParamsBurning, EXTERNAL_SALT, OUTBOUND_LIMIT, peerParams);

        // should not fail with a different external salt
        (address token2, address manager2, address transceiver2,) =
            factory.deployNtt(mode, tokenParamsBurning, "DIFFERENT_SALT", OUTBOUND_LIMIT, peerParams);

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
        IManagerBase.Mode mode = IManagerBase.Mode.LOCKING;

        PeersLibrary.PeerParams[] memory peerParams = new PeersLibrary.PeerParams[](1);
        peerParams[0] = PeersLibrary.PeerParams({peerChainId: 2, decimals: 18, inboundLimit: OUTBOUND_LIMIT});

        // Deploy twice with same parameters
        (address token1, address manager1, address transceiver1,) =
            factory.deployNtt(mode, tokenParamsLocking, EXTERNAL_SALT, OUTBOUND_LIMIT, peerParams);

        vm.expectRevert(); // Should revert on second deployment with same parameters
        factory.deployNtt(mode, tokenParamsLocking, EXTERNAL_SALT, OUTBOUND_LIMIT, peerParams);

        // should not fail with a different external salt
        (address token2, address manager2, address transceiver2,) =
            factory.deployNtt(mode, tokenParamsLocking, "DIFFERENT_SALT", OUTBOUND_LIMIT, peerParams);

        // Verify first deployment was successful
        assertTrue(token1 != address(0));
        assertTrue(manager1 != address(0));
        assertTrue(transceiver1 != address(0));

        // Verify second deployment was successful
        assertTrue(token2 != address(0));
        assertTrue(manager2 != address(0));
        assertTrue(transceiver2 != address(0));
    }

    function test_OwnershipAfterDeployNttBurning() public {
        IManagerBase.Mode mode = IManagerBase.Mode.BURNING;

        PeersLibrary.PeerParams[] memory peerParams = new PeersLibrary.PeerParams[](1);
        peerParams[0] = PeersLibrary.PeerParams({peerChainId: 2, decimals: 18, inboundLimit: OUTBOUND_LIMIT});

        // Deploy twice with same parameters
        (address token1, address manager1, address transceiver1, address ownerContract) =
            factory.deployNtt(mode, tokenParamsLocking, EXTERNAL_SALT, OUTBOUND_LIMIT, peerParams);

        assertEq(Ownable(token1).owner(), OWNER);
        assertEq(Ownable(manager1).owner(), ownerContract);
        assertEq(Ownable(transceiver1).owner(), ownerContract);
    }

    function test_OwnershipAfterDeployNttLocking() public {
        IManagerBase.Mode mode = IManagerBase.Mode.LOCKING;

        PeersLibrary.PeerParams[] memory peerParams = new PeersLibrary.PeerParams[](1);
        peerParams[0] = PeersLibrary.PeerParams({peerChainId: 2, decimals: 18, inboundLimit: OUTBOUND_LIMIT});

        // Deploy twice with same parameters
        (address token1, address manager1, address transceiver1, address ownerContract) =
            factory.deployNtt(mode, tokenParamsLocking, EXTERNAL_SALT, OUTBOUND_LIMIT, peerParams);

        assertEq(Ownable(token1).owner(), EXISTING_TOKEN_OWNER);
        assertEq(Ownable(manager1).owner(), ownerContract);
        assertEq(Ownable(transceiver1).owner(), ownerContract);
    }

    function test_setPeersAfterDeploy() public {
        IManagerBase.Mode mode = IManagerBase.Mode.BURNING;

        PeersLibrary.PeerParams[] memory peerParams1 = new PeersLibrary.PeerParams[](1);
        peerParams1[0] = PeersLibrary.PeerParams({peerChainId: 2, decimals: 18, inboundLimit: OUTBOUND_LIMIT});

        PeersLibrary.PeerParams[] memory peerParams2 = new PeersLibrary.PeerParams[](1);
        peerParams2[0] = PeersLibrary.PeerParams({peerChainId: 3, decimals: 8, inboundLimit: OUTBOUND_LIMIT});

        (, address manager, address transceiver, address ownerContract) =
            factory.deployNtt(mode, tokenParamsBurning, EXTERNAL_SALT, OUTBOUND_LIMIT, peerParams1);

        vm.startPrank(address(OWNER));
        NttOwner(ownerContract).setPeers(manager, transceiver, peerParams2);
        vm.stopPrank();

        INttManager.NttManagerPeer memory peer =
            INttManager.NttManagerPeer({tokenDecimals: 8, peerAddress: PeersLibrary.normalizeAddress(address(manager))});
        assertEq(INttManager(manager).getPeer(3).tokenDecimals, peer.tokenDecimals);
        assertEq(INttManager(manager).getPeer(3).peerAddress, peer.peerAddress);

        vm.startPrank(address(0x25));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x25)));
        NttOwner(ownerContract).setPeers(manager, transceiver, peerParams2);
    }

    function test_setPeerUsingExecute() public {
        IManagerBase.Mode mode = IManagerBase.Mode.BURNING;

        PeersLibrary.PeerParams[] memory peerParams1 = new PeersLibrary.PeerParams[](1);
        peerParams1[0] = PeersLibrary.PeerParams({peerChainId: 2, decimals: 18, inboundLimit: OUTBOUND_LIMIT});

        (, address manager,, address ownerContract) =
            factory.deployNtt(mode, tokenParamsBurning, EXTERNAL_SALT, OUTBOUND_LIMIT, peerParams1);

        vm.startPrank(address(OWNER));
        bytes4 selector = bytes4(keccak256("setPeer(uint16,bytes32,uint8,uint256)"));
        bytes32 peerAddress = PeersLibrary.normalizeAddress(address(manager));
        bytes memory data = abi.encodePacked(selector, abi.encode(4, peerAddress, 4, OUTBOUND_LIMIT));
        NttOwner(ownerContract).execute(manager, data);
        vm.stopPrank();

        assertEq(INttManager(manager).getPeer(4).tokenDecimals, 4);
        assertEq(INttManager(manager).getPeer(4).peerAddress, peerAddress);

        vm.startPrank(address(0x25));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x25)));
        NttOwner(ownerContract).execute(manager, data);
    }

    function test_supportInterface() public view {
        bytes4 NTT_FACTORY_INTERFACE_ID = type(INttFactory).interfaceId;

        assertTrue(factory.supportsInterface(NTT_FACTORY_INTERFACE_ID)); // INttFactory
        assertTrue(factory.supportsInterface(0x01ffc9a7)); // IERC165
    }

    function test_initializeManagerBytecode() public {
        address notDeployer = address(0x31);

        vm.startPrank(OWNER);
        NttFactory factory1 = new NttFactory(OWNER, "0.0.1");
        vm.stopPrank(); // Stop prank from owner

        vm.startPrank(notDeployer);
        vm.expectRevert(abi.encodeWithSelector(INttFactory.NotDeployer.selector));
        factory1.initializeManagerBytecode(mockManagerBytecode);
        vm.stopPrank();

        vm.startPrank(OWNER);
        // invalidBytecodes
        vm.expectRevert(abi.encodeWithSelector(INttFactory.InvalidBytecodes.selector));
        factory1.initializeManagerBytecode(bytes(""));

        // not reverted initialized successfully
        factory1.initializeManagerBytecode(mockManagerBytecode);

        vm.expectRevert(abi.encodeWithSelector(INttFactory.ManagerBytecodeAlreadyInitialized.selector));
        factory1.initializeManagerBytecode(mockManagerBytecode);
    }

    function test_initializeTransceiverBytecode() public {
        address notDeployer = address(0x31);

        vm.startPrank(OWNER);
        NttFactory factory1 = new NttFactory(OWNER, "0.0.1");
        vm.stopPrank(); // Stop prank from owner

        vm.startPrank(notDeployer);
        vm.expectRevert(abi.encodeWithSelector(INttFactory.NotDeployer.selector));
        factory1.initializeTransceiverBytecode(mockTransceiverBytecode);
        vm.stopPrank();

        vm.startPrank(OWNER);
        // invalidBytecodes
        vm.expectRevert(abi.encodeWithSelector(INttFactory.InvalidBytecodes.selector));
        factory1.initializeTransceiverBytecode(bytes(""));

        // not reverted initialized successfully
        factory1.initializeTransceiverBytecode(mockTransceiverBytecode);

        vm.expectRevert(abi.encodeWithSelector(INttFactory.TransceiverBytecodeAlreadyInitialized.selector));
        factory1.initializeTransceiverBytecode(mockTransceiverBytecode);
    }

    function test_initializeWormholeConfig() public {
        address notDeployer = address(0x31);
        uint16 chainId = wormhole.chainId();

        vm.startPrank(OWNER);
        NttFactory factory1 = new NttFactory(OWNER, "0.0.1");
        vm.stopPrank(); // Stop prank from owner

        vm.startPrank(notDeployer);
        vm.expectRevert(abi.encodeWithSelector(INttFactory.NotDeployer.selector));
        factory1.initializeWormholeConfig(address(wormhole), address(0x2), address(0x3), chainId);
        vm.stopPrank();

        // not reverted initialized successfully
        vm.startPrank(OWNER);
        factory1.initializeWormholeConfig(address(wormhole), address(0x2), address(0x3), chainId);

        vm.expectRevert(abi.encodeWithSelector(INttFactory.WormholeConfigAlreadyInitialized.selector));
        factory1.initializeWormholeConfig(address(wormhole), address(0x2), address(0x3), chainId);
    }
}
