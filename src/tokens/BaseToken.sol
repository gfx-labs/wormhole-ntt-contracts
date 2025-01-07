// SPDX-License-Identifier: Apache 2
pragma solidity 0.8.22;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Nonces} from "lib/openzeppelin-contracts/contracts/utils/Nonces.sol";

contract BaseToken is ERC20, ERC20Permit {
    constructor(string memory _name, string memory _symbol) ERC20Permit(_name) ERC20(_name, _symbol) {}

    function nonces(address _owner) public view override(ERC20Permit) returns (uint256) {
        return Nonces.nonces(_owner);
    }
}
