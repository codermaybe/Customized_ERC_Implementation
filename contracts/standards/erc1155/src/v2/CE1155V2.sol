// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1155} from "../interface/ERC1155.sol";
import {ERC1155TokenReceiver} from "../interface/ERC1155TokenReceiver.sol";

/**
 * @title CE1155V2 (Customized ERC1155)
 * @author github.com/codermaybe
 * @notice 沿袭 V1 的 THE OASIS 设计：FT/NFT 混合道具、单物品授权 + forAll、管理员体系。
 * @dev V2 迭代点：
 *      - 管理权限升级为两步所有权（owner/pendingOwner）；
 *      - ItemType 独立管理（create/update）；
 *      - 保留 V1 的“单物品额度授权”语义，并统一到标准 ERC1155 转账路径；
 *      - 批量/单笔路径统一在内部 update 中做余额与事件处理（CEI）。
 */
contract CE1155V2 is ERC1155 {
    error NotOwner();
    error ZeroAddress();
    error ItemTypeNotExists(uint256 id);
    error ItemTypeAlreadyExists(uint256 id);
    error Unauthorized();
    error InsufficientBalance(uint256 balance, uint256 needed);
    error LengthMismatch();
    error NFTAmountInvalid();
    error NFTBalanceInvalid();
    error NFTAlreadyAssigned(uint256 id);
    error InvalidNewOwner();
    error PendingOwnerExists();
    error PendingOwnerNotSet();
    error UnauthorizedPendingOwner();
    error InvalidOperator();
    error NFTTypeChangeBlocked(uint256 id);
    error InvalidReceiver();

    // ------------------------------------------------------------------------
    // Ownership（两步所有权）
    // ------------------------------------------------------------------------

    address public _contractOwner;
    address public _pendingOwner;

    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event OwnershipTransferRequested(
        address indexed oldOwner,
        address indexed pendingOwner
    );
    event OwnershipTransferCancelled(address indexed owner);

    modifier onlyOwner() {
        if (msg.sender != _contractOwner) revert NotOwner();
        _;
    }

    // ------------------------------------------------------------------------
    // Metadata & BaseURI
    // ------------------------------------------------------------------------

    string internal _name;
    string internal _symbol;
    string internal _baseURI;

    event BaseURIChanged(string oldBaseURI, string newBaseURI);

    // ------------------------------------------------------------------------
    // ItemType（沿袭 V1 的道具中心设计）
    // ------------------------------------------------------------------------

    struct ItemType {
        string name;
        string uri;
        bool isNFT;
        bool exists;
    }

    mapping(uint256 => ItemType) internal _itemTypes;
    mapping(uint256 => address) internal _nftOwnerOf;

    event ItemTypeCreated(
        uint256 indexed id,
        string name,
        string uri,
        bool isNFT
    );

    event ItemTypeUpdated(
        uint256 indexed id,
        string name,
        string uri,
        bool isNFT
    );

    // ------------------------------------------------------------------------
    // Balances & Approvals
    // ------------------------------------------------------------------------

    mapping(address => mapping(uint256 => uint256)) internal _balances;
    mapping(address => mapping(address => bool)) internal _approvalForAll;
    mapping(address => mapping(address => mapping(uint256 => uint256)))
        internal _singleAllowance;

    event SingleApproval(
        address indexed owner,
        address indexed operator,
        uint256 indexed id,
        uint256 amount
    );

    // ------------------------------------------------------------------------
    // ERC1155 Receiver 魔术值常量
    // ------------------------------------------------------------------------

    bytes4 internal constant _ERC1155_ACCEPTED = 0xf23a6e61;
    bytes4 internal constant _ERC1155_BATCH_ACCEPTED = 0xbc197c81;

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_
    ) {
        _contractOwner = msg.sender;
        _name = name_;
        _symbol = symbol_;
        _baseURI = baseURI_;
    }

    // ------------------------------------------------------------------------
    // ERC1155 标准接口
    // ------------------------------------------------------------------------

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    ) external virtual override {
        if (_to == address(0)) revert ZeroAddress();
        if (!_itemTypes[_id].exists) revert ItemTypeNotExists(_id);
        if (_from == address(0)) revert ZeroAddress();
        if (!_isApprovedOrOwnerForSingle(msg.sender, _from, _id, _value))
            revert Unauthorized();

        _updateSingle(msg.sender, _from, _to, _id, _value, _data);
    }

    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external virtual override {
        if (_to == address(0)) revert ZeroAddress();
        if (_from == address(0)) revert ZeroAddress();
        if (_ids.length != _values.length) revert LengthMismatch();

        bool byOwnerOrForAll = (msg.sender == _from) ||
            _approvalForAll[_from][msg.sender];

        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 id = _ids[i];
            uint256 value = _values[i];
            if (!_itemTypes[id].exists) revert ItemTypeNotExists(id);

            if (!byOwnerOrForAll) {
                if (_singleAllowance[_from][msg.sender][id] < value)
                    revert Unauthorized();
            }

            if (_balances[_from][id] < value)
                revert InsufficientBalance(_balances[_from][id], value);

            if (_itemTypes[id].isNFT) {
                if (value != 1) revert NFTAmountInvalid();
                if (_balances[_from][id] != 1) revert NFTBalanceInvalid();
            }
        }

        _updateBatch(msg.sender, _from, _to, _ids, _values, _data);
    }

    function balanceOf(
        address _owner,
        uint256 _id
    ) external view virtual override returns (uint256) {
        return _balances[_owner][_id];
    }

    function balanceOfBatch(
        address[] calldata _owners,
        uint256[] calldata _ids
    ) external view virtual override returns (uint256[] memory) {
        if (_owners.length != _ids.length) revert LengthMismatch();
        uint256[] memory result = new uint256[](_owners.length);
        for (uint256 i = 0; i < _owners.length; i++) {
            result[i] = _balances[_owners[i]][_ids[i]];
        }
        return result;
    }

    function setApprovalForAll(
        address _operator,
        bool _approved
    ) external virtual override {
        _approvalForAll[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function isApprovedForAll(
        address _owner,
        address _operator
    ) external view virtual override returns (bool) {
        return _approvalForAll[_owner][_operator];
    }

    // ------------------------------------------------------------------------
    // Ownership API
    // ------------------------------------------------------------------------

    function transferOwnership(address newOwner) external virtual onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        if (newOwner == _contractOwner) revert InvalidNewOwner();
        if (_pendingOwner != address(0)) revert PendingOwnerExists();
        _pendingOwner = newOwner;
        emit OwnershipTransferRequested(_contractOwner, newOwner);
    }

    function acceptOwnership() external virtual {
        if (msg.sender != _pendingOwner) revert UnauthorizedPendingOwner();
        emit OwnerChanged(_contractOwner, _pendingOwner);
        _contractOwner = _pendingOwner;
        _pendingOwner = address(0);
    }

    function cancelOwnershipTransfer() external virtual onlyOwner {
        if (_pendingOwner == address(0)) revert PendingOwnerNotSet();
        _pendingOwner = address(0);
        emit OwnershipTransferCancelled(_contractOwner);
    }

    // ------------------------------------------------------------------------
    // ItemType 管理
    // ------------------------------------------------------------------------

    function createItemType(
        uint256 id,
        string calldata name_,
        string calldata uri_,
        bool isNFT
    ) external virtual onlyOwner {
        if (_itemTypes[id].exists) revert ItemTypeAlreadyExists(id);
        _itemTypes[id] = ItemType({
            name: name_,
            uri: uri_,
            isNFT: isNFT,
            exists: true
        });
        emit ItemTypeCreated(id, name_, uri_, isNFT);
        emit URI(uri(id), id);
    }

    function updateItemType(
        uint256 id,
        string calldata name_,
        string calldata uri_,
        bool isNFT
    ) external virtual onlyOwner {
        if (!_itemTypes[id].exists) revert ItemTypeNotExists(id);

        if (_itemTypes[id].isNFT != isNFT) {
            if (_nftOwnerOf[id] != address(0)) revert NFTTypeChangeBlocked(id);
        }

        _itemTypes[id].name = name_;
        _itemTypes[id].uri = uri_;
        _itemTypes[id].isNFT = isNFT;

        emit ItemTypeUpdated(id, name_, uri_, isNFT);
        emit URI(uri(id), id);
    }

    // ------------------------------------------------------------------------
    // Metadata API
    // ------------------------------------------------------------------------

    function setBaseURI(string calldata newBaseURI) external virtual onlyOwner {
        emit BaseURIChanged(_baseURI, newBaseURI);
        _baseURI = newBaseURI;
    }

    function name() external view virtual returns (string memory) {
        return _name;
    }

    function symbol() external view virtual returns (string memory) {
        return _symbol;
    }

    function uri(uint256 id) public view virtual returns (string memory) {
        if (!_itemTypes[id].exists) revert ItemTypeNotExists(id);

        if (bytes(_itemTypes[id].uri).length > 0) {
            return _itemTypes[id].uri;
        }

        return string(abi.encodePacked(_baseURI, _toString(id)));
    }

    // ------------------------------------------------------------------------
    // Mint / Burn
    // ------------------------------------------------------------------------

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external virtual onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (!_itemTypes[id].exists) revert ItemTypeNotExists(id);

        if (_itemTypes[id].isNFT) {
            if (amount != 1) revert NFTAmountInvalid();
            if (_nftOwnerOf[id] != address(0)) revert NFTAlreadyAssigned(id);
        }

        _updateSingle(msg.sender, address(0), to, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external virtual onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (ids.length != amounts.length) revert LengthMismatch();

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            if (!_itemTypes[id].exists) revert ItemTypeNotExists(id);
            if (_itemTypes[id].isNFT) {
                if (amount != 1) revert NFTAmountInvalid();
                if (_nftOwnerOf[id] != address(0)) revert NFTAlreadyAssigned(id);
            }
        }

        _updateBatch(msg.sender, address(0), to, ids, amounts, data);
    }

    function burn(address from, uint256 id, uint256 amount) external virtual {
        if (from == address(0)) revert ZeroAddress();
        if (!_itemTypes[id].exists) revert ItemTypeNotExists(id);
        if (!_isApprovedOrOwnerForSingle(msg.sender, from, id, amount))
            revert Unauthorized();

        _updateSingle(msg.sender, from, address(0), id, amount, "");
    }

    function burnBatch(
        address from,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external virtual {
        if (from == address(0)) revert ZeroAddress();
        if (ids.length != amounts.length) revert LengthMismatch();

        bool byOwnerOrForAll = (msg.sender == from) ||
            _approvalForAll[from][msg.sender];

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            if (!_itemTypes[id].exists) revert ItemTypeNotExists(id);
            if (_balances[from][id] < amount)
                revert InsufficientBalance(_balances[from][id], amount);
            if (!byOwnerOrForAll) {
                if (_singleAllowance[from][msg.sender][id] < amount)
                    revert Unauthorized();
            }
            if (_itemTypes[id].isNFT) {
                if (amount != 1) revert NFTAmountInvalid();
                if (_balances[from][id] != 1) revert NFTBalanceInvalid();
            }
        }

        _updateBatch(msg.sender, from, address(0), ids, amounts, "");
    }

    // ------------------------------------------------------------------------
    // 单物品授权
    // ------------------------------------------------------------------------

    function setApprovalForSingle(
        address operator,
        uint256 id,
        uint256 amount
    ) external virtual {
        if (operator == address(0)) revert InvalidOperator();
        if (!_itemTypes[id].exists) revert ItemTypeNotExists(id);
        if (_balances[msg.sender][id] < amount)
            revert InsufficientBalance(_balances[msg.sender][id], amount);

        _singleAllowance[msg.sender][operator][id] = amount;
        emit SingleApproval(msg.sender, operator, id, amount);
    }

    // ------------------------------------------------------------------------
    // Internal core
    // ------------------------------------------------------------------------

    function _updateSingle(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) internal virtual {
        if (from == address(0)) {
            _balances[to][id] += value;
        } else if (to == address(0)) {
            _balances[from][id] -= value;
        } else {
            bool byOwnerOrForAll = (operator == from) ||
                _approvalForAll[from][operator];
            if (!byOwnerOrForAll) {
                _singleAllowance[from][operator][id] -= value;
                emit SingleApproval(
                    from,
                    operator,
                    id,
                    _singleAllowance[from][operator][id]
                );
            }

            _balances[from][id] -= value;
            _balances[to][id] += value;
        }

        if (_itemTypes[id].isNFT) {
            if (from == address(0)) {
                _nftOwnerOf[id] = to;
            } else if (to == address(0)) {
                _nftOwnerOf[id] = address(0);
            } else {
                _nftOwnerOf[id] = to;
            }
        }

        emit TransferSingle(operator, from, to, id, value);

        if (to != address(0)) {
            _requireOnReceived(operator, from, to, id, value, data);
        }
    }

    function _updateBatch(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) internal virtual {
        if (from == address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                uint256 id = ids[i];
                uint256 value = values[i];
                _balances[to][id] += value;
                if (_itemTypes[id].isNFT) {
                    _nftOwnerOf[id] = to;
                }
            }
        } else if (to == address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                uint256 id = ids[i];
                uint256 value = values[i];
                _balances[from][id] -= value;
                if (_itemTypes[id].isNFT) {
                    _nftOwnerOf[id] = address(0);
                }
            }
        } else {
            bool byOwnerOrForAll = (operator == from) ||
                _approvalForAll[from][operator];

            for (uint256 i = 0; i < ids.length; i++) {
                uint256 id = ids[i];
                uint256 value = values[i];

                if (!byOwnerOrForAll) {
                    _singleAllowance[from][operator][id] -= value;
                    emit SingleApproval(
                        from,
                        operator,
                        id,
                        _singleAllowance[from][operator][id]
                    );
                }

                _balances[from][id] -= value;
                _balances[to][id] += value;

                if (_itemTypes[id].isNFT) {
                    _nftOwnerOf[id] = to;
                }
            }
        }

        emit TransferBatch(operator, from, to, ids, values);

        if (to != address(0)) {
            _requireOnBatchReceived(operator, from, to, ids, values, data);
        }
    }

    function _isApprovedOrOwnerForSingle(
        address spender,
        address from,
        uint256 id,
        uint256 value
    ) internal view virtual returns (bool) {
        if (spender == from) return true;
        if (_approvalForAll[from][spender]) return true;
        if (_singleAllowance[from][spender][id] >= value) return true;
        return false;
    }

    function _requireOnReceived(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) internal virtual {
        if (to.code.length > 0) {
            try
                ERC1155TokenReceiver(to).onERC1155Received(
                    operator,
                    from,
                    id,
                    value,
                    data
                )
            returns (bytes4 result) {
                if (result != _ERC1155_ACCEPTED) revert InvalidReceiver();
            } catch {
                revert InvalidReceiver();
            }
        }
    }

    function _requireOnBatchReceived(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) internal virtual {
        if (to.code.length > 0) {
            try
                ERC1155TokenReceiver(to).onERC1155BatchReceived(
                    operator,
                    from,
                    ids,
                    values,
                    data
                )
            returns (bytes4 result) {
                if (result != _ERC1155_BATCH_ACCEPTED)
                    revert InvalidReceiver();
            } catch {
                revert InvalidReceiver();
            }
        }
    }

    function _existsItemType(uint256 id) internal view virtual returns (bool) {
        return _itemTypes[id].exists;
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        temp = value;
        for (uint256 i = digits; i > 0; ) {
            buffer[--i] = bytes1(uint8(48 + (temp % 10)));
            temp /= 10;
        }
        return string(buffer);
    }

    uint256[50] private __gap;
}
