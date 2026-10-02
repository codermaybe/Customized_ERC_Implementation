// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {
    ERC721URIStorageUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import {
    ERC721BurnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";

/**
 * @title CE721V3_OpenZeppelin
 * @notice OpenZeppelin 参考实现：可升级 ERC721、URIStorage、Burnable 与两步所有权。
 */
contract CE721V3_OpenZeppelin is
    Initializable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    ERC721BurnableUpgradeable,
    Ownable2StepUpgradeable
{
    uint256 private _nextTokenId;
    uint256[49] private __gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory name_, string memory symbol_, address initialOwner) public initializer {
        __ERC721_init(name_, symbol_);
        __ERC721URIStorage_init();
        __ERC721Burnable_init();
        __Ownable_init(initialOwner);
        __Ownable2Step_init();
    }

    function version() external pure returns (string memory) {
        return "3";
    }

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
        tokenId = _nextTokenId;
        _safeMint(to, tokenId);
        _nextTokenId = tokenId + 1;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
