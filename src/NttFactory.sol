// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {PeerToken} from "vendor/tokens/PeerToken.sol";
import {CREATE3} from "solmate/utils/CREATE3.sol";

/**
 * @title NttFactory
 * @notice Factory contract for deploying cross-chain NTT tokens and their managers
 */
contract NttFactory is Ownable {
    struct DeploymentParams {
        address token;
        IManagerBase.Mode mode;
        uint16 wormholeChainId;
        uint64 rateLimitDuration;
        bool shouldSkipRatelimiter;
        address wormholeCoreBridge;
        address wormholeRelayerAddr;
        address specialRelayerAddr;
        uint8 consistencyLevel;
        uint256 gasLimit;
        uint256 outboundLimit;
    }

    // --- Events ---
    event TokenDeployed(
        address indexed token, string name, string symbol, address indexed minter, address indexed owner
    );
    event ManagerDeployed(address indexed manager, address indexed token);
    event PeerSet(address indexed manager, uint16 chainId, bytes32 peer);

    // --- Errors ---
    error ZeroAddress();
    error DeploymentFailed();
    error InvalidParameters();

    // --- State ---
    bytes32 public immutable VERSION;
    mapping(address => address) public tokenToManager;

    constructor(address _owner, bytes32 _version) Ownable(_owner) {
        if (_version == bytes32(0)) revert InvalidParameters();
        VERSION = _version;
    }

    /**
     * @notice Deploy a new NTT token and its manager
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _minter Initial minter address
     * @param _tokenOwner Token owner address
     * @return token Address of deployed token
     * @return manager Address of deployed manager
     */
    function deployNtt(string memory _name, string memory _symbol, address _minter, address _tokenOwner)
        external
        onlyOwner
        returns (address token, address manager)
    {
        if (_minter == address(0) || _tokenOwner == address(0)) revert ZeroAddress();
        if (bytes(_name).length == 0 || bytes(_symbol).length == 0) revert InvalidParameters();

        // Generate deterministic salts
        bytes32 tokenSalt = keccak256(abi.encodePacked(VERSION, "TOKEN", _name, _symbol));
        bytes32 managerSalt = keccak256(abi.encodePacked(VERSION, "MANAGER", _name, _symbol));

        // Deploy token
        token = CREATE3.deploy(
            tokenSalt,
            abi.encodePacked(type(PeerToken).creationCode, abi.encode(_name, _symbol, _minter, _tokenOwner)),
            0
        );
        if (token == address(0)) revert DeploymentFailed();

        // deploy manager

        // setPeer

        emit TokenDeployed(token, _name, _symbol, _minter, _tokenOwner);
        emit ManagerDeployed(manager, token);

        return (token, manager);
    }

    function deployNttManager(DeploymentParams memory params) internal returns (address) {
        // Deploy the Manager Implementation.
        NttManager implementation = new NttManager(
            params.token, params.mode, params.wormholeChainId, params.rateLimitDuration, params.shouldSkipRatelimiter
        );

        // NttManager Proxy
        NttManager nttManagerProxy = NttManager(address(new ERC1967Proxy(address(implementation), "")));

        nttManagerProxy.initialize();

        console2.log("NttManager:", address(nttManagerProxy));

        return address(nttManagerProxy);
    }

    // TODO upgrade implementation
}
