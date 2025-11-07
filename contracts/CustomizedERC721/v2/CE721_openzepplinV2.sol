// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CE721_OPV2 (OpenZeppelin ERC721 版本)
 * @dev 继承 OZ 的 ERC721URIStorage / ERC721Burnable / Ownable。
 *      提供 owner 铸造、按 tokenId 设置 URI、以及两步转移所有权。
 */
contract CE721_OPV2 is ERC721, ERC721URIStorage, ERC721Burnable, Ownable {
    // 自增 tokenId（可选）
    uint256 private _nextToken;

    // 两步转移
    address private _pendingOwner;
    event OwnershipTransferRequested(address indexed oldOwner, address indexed pendingOwner);
    event OwnershipTransferCancelled(address indexed owner);

    constructor(string memory name_, string memory symbol_, address initialOwner)
        ERC721(name_, symbol_)
        Ownable(initialOwner)
    {}

    // 所有权：发起 -> accept -> 可取消
    function transferOwnership(address newOwner) public override onlyOwner {
        require(newOwner != address(0), "new owner is zero");
        require(newOwner != owner(), "new owner is current");
        require(_pendingOwner == address(0), "pending in progress");
        _pendingOwner = newOwner;
        emit OwnershipTransferRequested(owner(), newOwner);
    }

    function acceptOwnership() public {
        require(msg.sender == _pendingOwner, "not pending owner");
        _transferOwnership(_pendingOwner);
        _pendingOwner = address(0);
    }

    function cancelOwnershipTransfer() public onlyOwner {
        require(_pendingOwner != address(0), "no pending owner");
        _pendingOwner = address(0);
        emit OwnershipTransferCancelled(owner());
    }

    // 铸造：owner 控制；支持直接设置 URI 或使用外部网关
    function mint(address to, uint256 tokenId) external onlyOwner {
        _mint(to, tokenId);
    }

    function safeMint(address to, uint256 tokenId) external onlyOwner {
        _safeMint(to, tokenId);
    }

    function safeMint(address to, uint256 tokenId, string memory uri) external onlyOwner {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function mintNext(address to) external onlyOwner returns (uint256 tokenId) {
        tokenId = _nextToken;
        _safeMint(to, tokenId);
        _nextToken = tokenId + 1;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
