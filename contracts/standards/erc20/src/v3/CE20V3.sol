// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "contracts/interfaces/erc20/IERC20.sol";
import {IERC20Metadata} from "contracts/interfaces/erc20/IERC20Metadata.sol";
import {
    CE20AllowanceExtensions,
    CE20MintBurn,
    CE20Permit
} from "contracts/standards/erc20/src/interfaces/CE20Extensions.sol";

/**
 * @title CE20V3
 * @notice 自实现的可升级 IERC20：initializer、两步所有权、mint/burn 与 EIP-2612 permit。
 * @dev V3 是后续代理升级的 storage layout 基线；新增状态变量必须从 __gap 中消耗槽位。
 */
contract CE20V3 is IERC20, IERC20Metadata, CE20AllowanceExtensions, CE20MintBurn, CE20Permit {
    // ---------------------- Storage layout ----------------------
    address public _contractOwner;
    address public _pendingOwner;

    uint64 private _initializedVersion;
    bool private _initializing;

    string internal _name;
    string internal _symbol;

    uint256 internal _totalSupply;
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;

    mapping(address => uint256) internal _nonces;
    bytes32 internal _DOMAIN_SEPARATOR;
    uint256 internal _INITIAL_CHAIN_ID;

    uint256[47] private __gap;

    // ---------------------- Constants ----------------------
    string internal constant _VERSION = "3";
    uint8 internal constant _DECIMALS = 18;

    bytes32 internal constant _PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 internal constant _EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    uint256 internal constant _SECP256K1N_HALF = 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

    // ---------------------- Events ----------------------
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event OwnershipTransferRequested(address indexed oldOwner, address indexed pendingOwner);
    event OwnershipTransferCancelled(address indexed owner);

    // ---------------------- Errors ----------------------
    error NotOwner();
    error ZeroAddress();
    error AlreadyInitialized();
    error InvalidNewOwner();
    error PendingOwnerExists();
    error PendingOwnerNotSet();
    error UnauthorizedPendingOwner();
    error InsufficientBalance(uint256 balance, uint256 needed);
    error AllowanceExceeded(uint256 allowance, uint256 needed);
    error AllowanceOverflowed(uint256 allowance, uint256 needed);
    error TotalSupplyOverflowed();
    error PermitExpired(uint256 deadline);
    error InvalidSignature();
    error InvalidSignatureV(uint8 v);
    error InvalidSignatureS(bytes32 s);

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

    function initialize(string memory name_, string memory symbol_) external initializer {
        _contractOwner = msg.sender;
        _name = name_;
        _symbol = symbol_;
        _INITIAL_CHAIN_ID = block.chainid;
        _DOMAIN_SEPARATOR = _buildDomainSeparator();
    }

    function version() external pure returns (string memory) {
        return _VERSION;
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

    // ---------------------- IERC20 ----------------------
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address owner) external view override returns (uint256) {
        return _balances[owner];
    }

    function transfer(address to, uint256 value) external override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        _spendAllowance(from, msg.sender, value);
        _transfer(from, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external override returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function name() external view override returns (string memory) {
        return _name;
    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function decimals() external pure override returns (uint8) {
        return _DECIMALS;
    }

    function increaseAllowance(address spender, uint256 addedValue) external override returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        if (type(uint256).max - currentAllowance < addedValue) {
            revert AllowanceOverflowed(currentAllowance, addedValue);
        }

        _approve(msg.sender, spender, currentAllowance + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external override returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        if (currentAllowance < subtractedValue) {
            revert AllowanceExceeded(currentAllowance, subtractedValue);
        }

        unchecked {
            _approve(msg.sender, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function mint(address to, uint256 value) external override onlyOwner returns (bool) {
        _mint(to, value);
        return true;
    }

    function burn(uint256 value) external override returns (bool) {
        _burn(msg.sender, value);
        return true;
    }

    function burnFrom(address from, uint256 value) external override returns (bool) {
        _spendAllowance(from, msg.sender, value);
        _burn(from, value);
        return true;
    }

    // ---------------------- EIP-2612 ----------------------
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        override
    {
        if (owner == address(0)) revert ZeroAddress();
        if (block.timestamp > deadline) revert PermitExpired(deadline);
        if (v != 27 && v != 28) revert InvalidSignatureV(v);
        if (uint256(s) > _SECP256K1N_HALF) revert InvalidSignatureS(s);

        uint256 nonce = _nonces[owner];
        bytes32 structHash = keccak256(abi.encode(_PERMIT_TYPEHASH, owner, spender, value, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
        address signer = ecrecover(digest, v, r, s);
        if (signer == address(0) || signer != owner) {
            revert InvalidSignature();
        }

        _nonces[owner] = nonce + 1;
        _approve(owner, spender, value);
    }

    function nonces(address owner) external view override returns (uint256) {
        return _nonces[owner];
    }

    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return _domainSeparator();
    }

    function _domainSeparator() internal view returns (bytes32) {
        if (block.chainid == _INITIAL_CHAIN_ID) return _DOMAIN_SEPARATOR;
        return _buildDomainSeparator();
    }

    function _buildDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(_name)),
                keccak256(bytes(_VERSION)),
                block.chainid,
                address(this)
            )
        );
    }

    // ---------------------- Internal IERC20 core ----------------------
    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();

        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) {
            revert InsufficientBalance(fromBalance, amount);
        }

        _beforeTokenTransfer(from, to, amount);
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        if (owner == address(0) || spender == address(0)) {
            revert ZeroAddress();
        }
        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = _allowances[owner][spender];
        if (currentAllowance == type(uint256).max) return;
        if (currentAllowance < amount) {
            revert AllowanceExceeded(currentAllowance, amount);
        }

        unchecked {
            _approve(owner, spender, currentAllowance - amount);
        }
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        if (type(uint256).max - _totalSupply < amount) {
            revert TotalSupplyOverflowed();
        }

        _beforeTokenTransfer(address(0), to, amount);
        unchecked {
            _totalSupply += amount;
            _balances[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ZeroAddress();

        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) {
            revert InsufficientBalance(fromBalance, amount);
        }

        _beforeTokenTransfer(from, address(0), amount);
        unchecked {
            _balances[from] = fromBalance - amount;
            _totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {
        from;
        to;
        amount;
    }
}
