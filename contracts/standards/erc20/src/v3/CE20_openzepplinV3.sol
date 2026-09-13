// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

/**
 * @title CE20_OPV3
 * @notice OpenZeppelin 参考实现：可升级 ERC20、Permit、两步所有权及 mint/burn。
 */
contract CE20_OPV3 is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    Ownable2StepUpgradeable
{
    uint256[50] private __gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        address initialOwner
    ) public initializer {
        __ERC20_init(name_, symbol_);
        __ERC20Permit_init(name_);
        __Ownable_init(initialOwner);
        __Ownable2Step_init();
    }

    function version() external pure returns (string memory) {
        return "3";
    }

    function mint(
        address to,
        uint256 amount
    ) external onlyOwner returns (bool) {
        _mint(to, amount);
        return true;
    }

    function burn(uint256 amount) external returns (bool) {
        _burn(_msgSender(), amount);
        return true;
    }

    function burnFrom(address from, uint256 amount) external returns (bool) {
        _spendAllowance(from, _msgSender(), amount);
        _burn(from, amount);
        return true;
    }
}
