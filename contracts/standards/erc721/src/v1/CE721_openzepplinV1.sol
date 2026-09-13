// SPDX-License-Identifier:MIT
pragma solidity ^0.8.28;
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title CustomizedERC20
 * @author github.com/codermaybe
 * @dev CustomizedERC20 is a customized ERC20 token with a few additional features.
 * @dev 本合约仅用于学习和研究。ERC721标准的实现依赖openzepplin库。详见：https://github.com/ethereum/ERCs/blob/master/ERCS/erc-721.md
 * @dev V1版本特性：
 * @dev 1. 继承了ERC721URIStorage和ERC721Burnable，支持URI和Burn功能。
 * @dev 2. 继承了Ownable，支持owner的管理。
 * @dev 3. 重写了tokenURI和supportsInterface函数，支持ERC721标准的查询。
 */
contract CE721_openzepplinV1 is
    ERC721,
    ERC721URIStorage,
    ERC721Burnable,
    Ownable
{
    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) Ownable(msg.sender) {
        // 检查 name 和 symbol 是否为空
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        // 调用 Ownable 的构造函数，传递部署合约的地址作为所有者
        // Ownable 的构造函数会自动将部署者设置为所有者
    }

    //调用
    function safeMint(
        address to,
        uint256 tokenId,
        string memory uri
    ) public onlyOwner {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(
        uint256 tokenId
    )
        public
        view
        virtual
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}
