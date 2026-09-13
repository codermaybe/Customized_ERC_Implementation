// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CE20_OPV2 (OZ ERC20 + 自实现 Permit)
 * @notice 基于 OpenZeppelin 的 ERC20 + Ownable，内置自实现的 EIP-2612 permit（版本号为 "2"，与 CE20V2 对齐）。
 * @dev 特性：
 *      - decimals = 18（继承 ERC20 默认）；
 *      - onlyOwner 的 mint；
 *      - burn/burnFrom；
 *      - 自实现 EIP-2612 permit（不改动 OZ 源码），对外提供 nonces/DOMAIN_SEPARATOR/permit。
 */
contract CE20_OPV2 is ERC20, Ownable {
    // ---- EIP-2612: 自实现（版本号为 "2"） ----
    string internal _version = "2";
    mapping(address => uint256) internal _nonces;
    bytes32 internal _DOMAIN_SEPARATOR;
    uint256 internal _INITIAL_CHAIN_ID;
    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
    bytes32 internal constant _EIP712_DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    // ---- 自定义错误（与 CE20V2 对齐命名） ----
    error PermitExpired(uint256 deadline);
    error InvalidSignature();
    error ZeroAddress();
    constructor(
        string memory name_,
        string memory symbol_,
        address initialOwner
    ) ERC20(name_, symbol_) Ownable(initialOwner) {
        _INITIAL_CHAIN_ID = block.chainid;
        _DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                _EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(name_)),
                keccak256(bytes(_version)),
                block.chainid,
                address(this)
            )
        );
    }

    /// @notice 仅所有者可铸造
    function mint(address to, uint256 amount) public onlyOwner returns (bool) {
        _mint(to, amount);
        return true;
    }

    /// @notice 销毁调用者持有的代币
    function burn(uint256 amount) public returns (bool) {
        _burn(_msgSender(), amount);
        return true;
    }

    /// @notice 从指定地址销毁（需有足够的 allowance）
    function burnFrom(address from, uint256 amount) public returns (bool) {
        _spendAllowance(from, _msgSender(), amount);
        _burn(from, amount);
        return true;
    }

    /// @notice EIP-2612: permit 签名授权（版本号为 "2"）
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        if (deadline < block.timestamp) revert PermitExpired(deadline);

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                _nonces[owner],
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", _domainSeparator(), structHash)
        );
        address signer = ecrecover(digest, v, r, s);
        if (signer == address(0)) revert ZeroAddress();
        if (signer != owner) revert InvalidSignature();

        _nonces[owner]++;
        _approve(owner, spender, value);
    }

    /// @notice EIP-2612: 每个 owner 的 nonce 值
    function nonces(address owner) external view returns (uint256) {
        return _nonces[owner];
    }

    /// @notice EIP-712: 域分隔符
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparator();
    }

    /// @dev 内部域分隔符：链 ID 改变时按当前链重算
    function _domainSeparator() internal view returns (bytes32) {
        if (block.chainid == _INITIAL_CHAIN_ID) return _DOMAIN_SEPARATOR;
        return keccak256(
            abi.encode(
                _EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(name())),
                keccak256(bytes(_version)),
                block.chainid,
                address(this)
            )
        );
    }
}
