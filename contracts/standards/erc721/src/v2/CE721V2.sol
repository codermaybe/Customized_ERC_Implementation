// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title CE721V2 (Customized ERC721)
 * @dev 外部薄壳路由；内部统一校验与状态更新（CEI）。
 */
import {IERC721} from "contracts/interfaces/erc721/IERC721.sol";
import {ERC165} from "contracts/interfaces/erc721/IERC721.sol";
import {IERC721Metadata} from "contracts/interfaces/erc721/IERC721Metadata.sol";
import {IERC721TokenReceiver} from "contracts/interfaces/erc721/IERC721TokenReceiver.sol";

contract CE721V2 is IERC721, IERC721Metadata, ERC165 {
    error NotOwner();
    error ZeroAddress();
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

    // 存储
    mapping(address => uint256) internal _balanceOf;
    mapping(uint256 => address) internal _ownerOf;
    mapping(uint256 => address) internal _approvedOf;
    mapping(address => mapping(address => bool)) internal _approvalForAll;

    // 合约管理员
    address public _contractOwner;
    // 二步转移
    address public _pendingOwner;
    // 所有权事件
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event OwnershipTransferRequested(address indexed oldOwner, address indexed pendingOwner);
    event OwnershipTransferCancelled(address indexed owner);

    // 元数据
    string internal _name;
    string internal _symbol;

    string internal _baseURI;
    event BaseUriChanged(string _oldURI, string _newURI);

    // 递增 tokenId（可选）
    uint256 public _nextToken;

    // ERC721Receiver 魔术值（0x150b7a02）
    bytes4 internal constant _ERC721_RECEIVED = 0x150b7a02;

    // 构造器：初始化 owner/name/symbol/baseURI/_nextToken
    constructor(string memory name_, string memory symbol_, string memory baseURI_) {
        // 初始化基本元数据与所有者
        _contractOwner = msg.sender;
        _name = name_;
        _symbol = symbol_;
        _baseURI = baseURI_;
        _nextToken = 0;
    }

    modifier onlyOwner() {
        if (msg.sender != _contractOwner) revert NotOwner();
        _;
    }

    // -------------------- ERC165 --------------------
    // ERC165: 接口支持查询
    function supportsInterface(bytes4 interfaceID) external pure returns (bool) {
        if (interfaceID == 0x01ffc9a7) return true; // ERC165
        if (interfaceID == 0x80ac58cd) return true; // ERC721
        if (interfaceID == 0x5b5e139f) return true; // ERC721Metadata
        return false;
    }

    // -------------------- ERC721Metadata --------------------
    // Metadata: name()
    function name() external view returns (string memory) {
        return _name;
    }

    // Metadata: symbol()
    function symbol() external view returns (string memory) {
        return _symbol;
    }

    // Metadata: tokenURI(tokenId)
    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        // 返回 BaseURI + tokenId
        if (!_exists(_tokenId)) revert TokenNotExists(_tokenId);
        return string(abi.encodePacked(_baseURI, _toString(_tokenId)));
    }

    // -------------------- 管理 --------------------
    // 管理：发起二步转移（设置 pendingOwner 并记录事件）
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        if (newOwner == _contractOwner) revert InvalidNewOwner();
        if (_pendingOwner != address(0)) revert PendingOwnerExists();
        _pendingOwner = newOwner;
        emit OwnershipTransferRequested(_contractOwner, newOwner);
    }

    // 接受所有权（由 _pendingOwner 调用）
    function acceptOwnership() external {
        // 完成变更并清空
        if (msg.sender != _pendingOwner) revert UnauthorizedPendingOwner();
        emit OwnerChanged(_contractOwner, _pendingOwner);
        _contractOwner = _pendingOwner;
        _pendingOwner = address(0);
    }

    // 取消所有权转移（仅 owner）
    function cancelOwnershipTransfer() external onlyOwner {
        if (_pendingOwner == address(0)) revert PendingOwnerNotSet();
        _pendingOwner = address(0);
        emit OwnershipTransferCancelled(_contractOwner);
    }

    // 设置 BaseURI
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        emit BaseUriChanged(_baseURI, newBaseURI);
        _baseURI = newBaseURI;
    }

    // ERC721: 余额与拥有者查询
    function balanceOf(address _owner) external view returns (uint256) {
        if (_owner == address(0)) revert ZeroAddress();
        return _balanceOf[_owner];
    }

    // ownerOf(tokenId)
    function ownerOf(uint256 _tokenId) external view returns (address) {
        if (_ownerOf[_tokenId] == address(0)) revert TokenNotExists(_tokenId);
        return _ownerOf[_tokenId];
    }

    // 转移：外部路由；内部 `_transfer` 校验；safe 版追加回调
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory data) public payable {
        _transfer(_from, _to, _tokenId);
        _requireOnReceived(msg.sender, _from, _to, _tokenId, data);
    }

    // 转移：safeTransferFrom 重载（data 为空串）
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable {
        safeTransferFrom(_from, _to, _tokenId, bytes(""));
    }

    // 转移：非 safe 版（不做回调）
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable {
        _transfer(_from, _to, _tokenId);
    }

    // -------------------- 授权 --------------------
    // approve：外部路由（校验与写入在 _approve）
    function approve(address _approved, uint256 _tokenId) external payable {
        _approve(_approved, _tokenId, _ownerOf[_tokenId]);
    }

    // setApprovalForAll：设置/撤销操作员
    function setApprovalForAll(address _operator, bool _approved) external {
        _approvalForAll[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    // getApproved：查询单一授权（token 必须存在）
    function getApproved(uint256 _tokenId) external view returns (address) {
        if (!_exists(_tokenId)) revert TokenNotExists(_tokenId);
        return _approvedOf[_tokenId];
    }

    // ERC721: 全局授权查询
    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return _approvalForAll[_owner][_operator];
    }

    // 铸造/销毁
    function mint(address to, uint256 tokenId) external onlyOwner {
        _mint(to, tokenId);
    }

    // 铸造：safe 版（带 data）
    function safeMint(address to, uint256 tokenId, bytes memory data) external onlyOwner {
        _mint(to, tokenId);
        _requireOnReceived(msg.sender, address(0), to, tokenId, data);
    }

    // 铸造：safe 版（data 空串）
    function safeMint(address to, uint256 tokenId) external onlyOwner {
        _mint(to, tokenId);
        _requireOnReceived(msg.sender, address(0), to, tokenId, bytes(""));
    }

    // 铸造：使用 _nextToken 自增
    function mintNext(address to) external onlyOwner returns (uint256 tokenId) {
        uint256 tokenId_ = _nextToken;
        _mint(to, tokenId_);
        _nextToken += 1;
        return tokenId_;
    }

    // 销毁：外部路由
    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }

    // -------------------- 内部：核心逻辑 --------------------
    // _exists：判断 token 是否存在（owner 非零）
    function _exists(uint256 tokenId) internal view returns (bool) {
        // owner 非零表示存在
        if (_ownerOf[tokenId] != address(0)) return true;
        return false;
    }

    // _isApprovedOrOwner：是否为 owner/单一授权/全局授权
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address tokenOwner = _ownerOf[tokenId];
        if (tokenOwner == address(0)) revert TokenNotExists(tokenId);
        if (_approvedOf[tokenId] == spender || tokenOwner == spender) {
            return true;
        }
        return _approvalForAll[tokenOwner][spender];
    }

    // _approve：设置单一授权并触发事件
    function _approve(address to, uint256 tokenId, address owner) internal {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);
        if (msg.sender != _ownerOf[tokenId] && !_approvalForAll[owner][msg.sender]) revert NotAuthorized();
        if (to == owner) revert ApproveToCurrentOwner();
        _approvedOf[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    // _transfer：统一校验 + 状态 + 事件（不做外部交互）
    function _transfer(address from, address to, uint256 tokenId) internal {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert NotAuthorized();
        if (from != _ownerOf[tokenId]) revert InvalidFrom(from, _ownerOf[tokenId]);
        if (to == address(0)) revert ZeroAddress();
        _approvedOf[tokenId] = address(0);
        _balanceOf[from] -= 1;
        _balanceOf[to] += 1;
        _ownerOf[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    // _mint：校验 + 状态 + 事件
    function _mint(address to, uint256 tokenId) internal onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (_exists(tokenId)) revert TokenAlreadyExists(tokenId);
        _balanceOf[to] += 1;
        _ownerOf[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }

    // _burn：校验 + 状态 + 事件
    function _burn(uint256 tokenId) internal {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);
        address owner = _ownerOf[tokenId];
        if (!_isApprovedOrOwner(msg.sender, tokenId) && msg.sender != _contractOwner) revert NotAuthorized();
        _approvedOf[tokenId] = address(0);
        _balanceOf[owner] -= 1;
        _ownerOf[tokenId] = address(0);
        emit Transfer(owner, address(0), tokenId);
    }

    // _requireOnReceived：to 为合约时校验 onERC721Received 返回值
    function _requireOnReceived(address operator, address from, address to, uint256 tokenId, bytes memory data)
        internal
    {
        if (to.code.length > 0) {
            try IERC721TokenReceiver(to).onERC721Received(operator, from, tokenId, data) returns (bytes4 result) {
                if (result != _ERC721_RECEIVED) revert InvalidReceiver();
            } catch {
                revert InvalidReceiver();
            }
        }
    }

    // -------------------- 内部：工具 --------------------
    // _toString：uint256 -> string
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        temp = value;
        for (uint256 i = digits; i > 0;) {
            buffer[--i] = bytes1(uint8(48 + (temp % 10)));
            temp /= 10;
        }
        return string(buffer);
    }
}
