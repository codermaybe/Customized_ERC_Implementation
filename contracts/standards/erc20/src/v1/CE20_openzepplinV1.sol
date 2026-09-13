// SPDX-License-Identifier: MIT
/**
 * @title CustomizedERC20_Openzepplin
 * @author github.com/codermaybe
 * @dev CustomizedERC20_Openzepplin is a customized ERC20 token with a few additional features.
 * @dev 使用openzepplin的erc20合约，自行添加Burn,mint方法,暂时仅由拥有者操控
 */
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CE20_OPV1 is ERC20, Ownable {
    constructor(
        uint256 initialSupply
    ) ERC20("CE20_OPV1", "CE20_OPV1") Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
    }

    event Burn(address _from, uint256 _value);

    function burn(address _from, uint256 _value) public onlyOwner {
        _burn(_from, _value);
        emit Burn(_from, _value);
    }

    event Mint(address _to, uint256 _value);

    function mint(address _to, uint256 _value) public onlyOwner {
        _mint(_to, _value);
        emit Mint(_to, _value);
    }
}
