// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721, ERC165} from "../interface/ERC721.sol";
import {ERC721Metadata} from "../interface/ERC721Metadata.sol";
import {ERC721TokenReceiver} from "../interface/ERC721TokenReceiver.sol";

/**
 * @title CE721V3
 * @notice 自实现的可升级 ERC721，延续 V2 行为并以 initializer 替代 constructor。
 * @dev V3 是后续代理升级的 storage layout 基线；新增状态变量必须从 __gap 中消耗槽位。
 */
contract CE721V3 is ERC721, ERC721Metadata, ERC165 {
    // ---------------------- Storage layout ----------------------
    address public _contractOwner;
    address public _pendingOwner;

    uint64 private _initializedVersion;
    bool private _initializing;

    string internal _name;
    string internal _symbol;
    string internal _baseURI;

    mapping(address => uint256) internal _balanceOf;
    mapping(uint256 => address) internal _ownerOf;
    mapping(uint256 => address) internal _approvedOf;
    mapping(address => mapping(address => bool)) internal _approvalForAll;

    uint256 public _nextToken;

    uint256[45] private __gap;

    bytes4 internal constant _ERC721_RECEIVED = 0x150b7a02;

    // ---------------------- Events ----------------------
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event OwnershipTransferRequested(
        address indexed oldOwner,
        address indexed pendingOwner
    );
    event OwnershipTransferCancelled(address indexed owner);
    event BaseUriChanged(string oldURI, string newURI);

    // ---------------------- Errors ----------------------
    error NotOwner();
    error ZeroAddress();
    error AlreadyInitialized();
    error TokenNotExists(uint256 tokenId);
    error PendingOwnerExists();
    error PendingOwnerNotSet();
    error UnauthorizedPendingOwner();
    error InvalidNewOwner();
    error NotAuthorized();
    error InvalidFrom(address from, address actualOwner);
    error ApproveToCurrentOwner();
    error TokenAlreadyExists(uint256 tokenId);
    error InvalidReceiver();
    error InvalidOperator();

    modifier onlyOwner() {
        if (msg.sender != _contractOwner) revert NotOwner();
        _;
    }

    modifier initializer() {
        if (_initializing || _initializedVersion != 0) {
            revert AlreadyInitialized();
        }
        _initializedVersion = 1;
        _initializing = true;
        _;
        _initializing = false;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _initializedVersion = type(uint64).max;
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        string memory baseURI_
    ) external initializer {
        _contractOwner = msg.sender;
        _name = name_;
        _symbol = symbol_;
        _baseURI = baseURI_;
    }

    function version() external pure returns (string memory) {
        return "3";
    }

    // ---------------------- ERC165 / metadata ----------------------
    function supportsInterface(
        bytes4 interfaceID
    ) external pure override returns (bool) {
        return
            interfaceID == 0x01ffc9a7 ||
            interfaceID == 0x80ac58cd ||
            interfaceID == 0x5b5e139f;
    }

    function name() external view override returns (string memory) {
        return _name;
    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function tokenURI(
        uint256 tokenId
    ) external view override returns (string memory) {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);
        return string(abi.encodePacked(_baseURI, _toString(tokenId)));
    }

    // ---------------------- Ownership ----------------------
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        if (newOwner == _contractOwner) revert InvalidNewOwner();
        if (_pendingOwner != address(0)) revert PendingOwnerExists();

        _pendingOwner = newOwner;
        emit OwnershipTransferRequested(_contractOwner, newOwner);
    }

    function acceptOwnership() external {
        address pendingOwner = _pendingOwner;
        if (msg.sender != pendingOwner) revert UnauthorizedPendingOwner();

        emit OwnerChanged(_contractOwner, pendingOwner);
        _contractOwner = pendingOwner;
        _pendingOwner = address(0);
    }

    function cancelOwnershipTransfer() external onlyOwner {
        if (_pendingOwner == address(0)) revert PendingOwnerNotSet();
        _pendingOwner = address(0);
        emit OwnershipTransferCancelled(_contractOwner);
    }

    function setBaseURI(string memory newBaseURI) external onlyOwner {
        emit BaseUriChanged(_baseURI, newBaseURI);
        _baseURI = newBaseURI;
    }

    // ---------------------- ERC721 ----------------------
    function balanceOf(address owner) external view override returns (uint256) {
        if (owner == address(0)) revert ZeroAddress();
        return _balanceOf[owner];
    }

    function ownerOf(uint256 tokenId) external view override returns (address) {
        address owner = _ownerOf[tokenId];
        if (owner == address(0)) revert TokenNotExists(tokenId);
        return owner;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public payable override {
        _transfer(from, to, tokenId);
        _requireOnReceived(msg.sender, from, to, tokenId, data);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external payable override {
        safeTransferFrom(from, to, tokenId, bytes(""));
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external payable override {
        _transfer(from, to, tokenId);
    }

    function approve(
        address approved,
        uint256 tokenId
    ) external payable override {
        _approve(approved, tokenId, _ownerOf[tokenId]);
    }

    function setApprovalForAll(
        address operator,
        bool approved
    ) external override {
        if (operator == msg.sender) revert InvalidOperator();
        _approvalForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function getApproved(
        uint256 tokenId
    ) external view override returns (address) {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);
        return _approvedOf[tokenId];
    }

    function isApprovedForAll(
        address owner,
        address operator
    ) external view override returns (bool) {
        return _approvalForAll[owner][operator];
    }

    // ---------------------- Mint / burn ----------------------
    function mint(address to, uint256 tokenId) external onlyOwner {
        _mint(to, tokenId);
    }

    function safeMint(
        address to,
        uint256 tokenId,
        bytes memory data
    ) external onlyOwner {
        _mint(to, tokenId);
        _requireOnReceived(msg.sender, address(0), to, tokenId, data);
    }

    function safeMint(address to, uint256 tokenId) external onlyOwner {
        _mint(to, tokenId);
        _requireOnReceived(msg.sender, address(0), to, tokenId, bytes(""));
    }

    function mintNext(address to) external onlyOwner returns (uint256 tokenId) {
        tokenId = _nextToken;
        _mint(to, tokenId);
        _nextToken = tokenId + 1;
    }

    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }

    // ---------------------- Internal core ----------------------
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf[tokenId] != address(0);
    }

    function _isApprovedOrOwner(
        address spender,
        uint256 tokenId
    ) internal view returns (bool) {
        address tokenOwner = _ownerOf[tokenId];
        if (tokenOwner == address(0)) revert TokenNotExists(tokenId);
        return
            spender == tokenOwner ||
            spender == _approvedOf[tokenId] ||
            _approvalForAll[tokenOwner][spender];
    }

    function _approve(address to, uint256 tokenId, address owner) internal {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);
        if (msg.sender != owner && !_approvalForAll[owner][msg.sender])
            revert NotAuthorized();
        if (to == owner) revert ApproveToCurrentOwner();

        _approvedOf[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert NotAuthorized();

        address actualOwner = _ownerOf[tokenId];
        if (from != actualOwner) revert InvalidFrom(from, actualOwner);
        if (to == address(0)) revert ZeroAddress();

        delete _approvedOf[tokenId];
        unchecked {
            _balanceOf[from] -= 1;
            _balanceOf[to] += 1;
        }
        _ownerOf[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function _mint(address to, uint256 tokenId) internal {
        if (msg.sender != _contractOwner) revert NotOwner();
        if (to == address(0)) revert ZeroAddress();
        if (_exists(tokenId)) revert TokenAlreadyExists(tokenId);

        _balanceOf[to] += 1;
        _ownerOf[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }

    function _burn(uint256 tokenId) internal {
        address owner = _ownerOf[tokenId];
        if (owner == address(0)) revert TokenNotExists(tokenId);
        if (
            !_isApprovedOrOwner(msg.sender, tokenId) &&
            msg.sender != _contractOwner
        ) revert NotAuthorized();

        delete _approvedOf[tokenId];
        unchecked {
            _balanceOf[owner] -= 1;
        }
        delete _ownerOf[tokenId];
        emit Transfer(owner, address(0), tokenId);
    }

    function _requireOnReceived(
        address operator,
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal {
        if (to.code.length == 0) return;

        try
            ERC721TokenReceiver(to).onERC721Received(
                operator,
                from,
                tokenId,
                data
            )
        returns (bytes4 result) {
            if (result != _ERC721_RECEIVED) revert InvalidReceiver();
        } catch {
            revert InvalidReceiver();
        }
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";

        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            ++digits;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        temp = value;
        while (digits != 0) {
            unchecked {
                --digits;
            }
            buffer[digits] = bytes1(uint8(48 + (temp % 10)));
            temp /= 10;
        }
        return string(buffer);
    }
}
