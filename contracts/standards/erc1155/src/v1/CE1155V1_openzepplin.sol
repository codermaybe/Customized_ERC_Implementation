//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Burnable} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CustomizedERC1155_OpenZeppelin V1
 * @author github.com/codermaybe
 * @dev 学习版：基于 OpenZeppelin ERC1155 + Ownable + Burnable。
 * @dev 特性：
 *      - 构造时设置基础 URI、name、symbol；
 *      - onlyOwner 控制的 mint / mintBatch；
 *      - Burn 功能沿用 ERC1155Burnable：代币持有者或其授权人可以自行销毁。
 *
 * @notice 本合约仅作为对照实现，便于与自实现版本 CE1155V1.sol 对比。
 */
contract CE1155_OPV1 is ERC1155, ERC1155Burnable, Ownable {
    /// @dev ERC1155 标准本身没有 name/symbol，这里做简单扩展方便前端展示
    string public name;
    string public symbol;

    /**
     * @param uri_   ERC1155 基础 URI，通常包含 {id} 占位符
     * @param name_  项目名称（例如 "THE OASIS Items"）
     * @param symbol_ 项目标识（例如 "OASIS1155"）
     */
    constructor(
        string memory uri_,
        string memory name_,
        string memory symbol_
    ) ERC1155(uri_) Ownable(msg.sender) {
        name = name_;
        symbol = symbol_;
    }

    /**
     * @notice 铸造单一类型代币，仅 owner 可调用。
     * @param to      接收地址
     * @param id      代币 ID
     * @param amount  铸造数量
     * @param data    附加数据，将在接收者的 onERC1155Received 中原样传递
     */
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external onlyOwner {
        _mint(to, id, amount, data);
    }

    /**
     * @notice 批量铸造多种代币类型，仅 owner 可调用。
     * @param to      接收地址
     * @param ids     代币 ID 列表
     * @param amounts 对应数量列表（长度需与 ids 一致）
     * @param data    附加数据，将在接收者的 onERC1155BatchReceived 中原样传递
     */
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }
}
