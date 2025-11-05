// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title CE20V2 (Custom ERC20 with Permit)
 * @notice 最小可用实现：ERC20 + onlyOwner mint + burn/burnFrom + EIP‑2612（版本号 "2"）。
 * @dev 实现要点：
 *      1) 外部函数仅委托内部逻辑并返回（transfer/approve/...）；
 *      2) 事件归口：Approval 仅在 `_approve`，Transfer 仅在 `_transfer/_mint/_burn`；
 *      3) Hook：在状态写入前调用一次 `_beforeTokenTransfer(from,to,amount)`；
 *      4) 零地址语义：`_transfer` 禁止零地址；`_mint` 视为 0->to；`_burn` 视为 from->0；
 *      5) 自定义错误：ZeroAddress / InsufficientBalance / AllowanceExceeded / AllowanceOverflowed / PermitExpired / InvalidSignature。
 */
contract CE20V2 {
    // ---------------------- 状态与常量（可按需调整） ----------------------
    // 所有者（用于 mint 等最小权限控制）
    address internal _owner;

    // 代币元数据（名称、符号）
    string internal _name;
    string internal _symbol;

    //CE20V2版本固定
    string internal _version = "2";

    // Decimals 固定为 18（V2 约定）。实现时可直接返回该常量。
    uint8 internal constant _DECIMALS = 18;

    // 总供应与余额、授权
    uint256 internal _totalSupply;
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;

    // EIP-2612：签名与域相关（实现时初始化并返回）
    // 说明：EIP-712 域分隔符有两种常见实现取舍：
    //  - 缓存 + 链 ID 变化时重算（推荐、主流）：在构造中缓存 `_INITIAL_CHAIN_ID=block.chainid` 与 `_DOMAIN_SEPARATOR`；
    //    读取时若 `block.chainid==_INITIAL_CHAIN_ID` 直接返回缓存，否则按当前链 ID 现场重算。
    //    优点：多数场景少一次编码与 keccak 计算，更省 gas；与 OpenZeppelin EIP712/Permit 模式一致，生态兼容好。
    //  - 每次动态计算（更简洁）：不存缓存，`DOMAIN_SEPARATOR()` 内按 EIP-712 公式每次重算。
    //    优点：实现简单；缺点：每次多一笔编码/哈希开销，gas 略高。
    // 使用本方案时务必在构造/初始化中完成赋值，避免 DOMAIN_SEPARATOR 返回零值导致签名失效。
    mapping(address => uint256) internal _nonces;
    bytes32 internal _DOMAIN_SEPARATOR;
    uint256 internal _INITIAL_CHAIN_ID;
    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
    constructor(string memory name_, string memory symbol_) {
        _owner = msg.sender;
        _name = name_;
        _symbol = symbol_;
        _DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(_name)),
                keccak256(bytes(_version)),
                block.chainid,
                address(this)
            )
        );
        _INITIAL_CHAIN_ID = block.chainid;
    }

    // ---------------------- 事件（EIP-20） ----------------------
    /// @notice 在任意代币转账（包括铸造与销毁）时触发。
    /// @dev 铸造：`from` 为零地址；销毁：`to` 为零地址。
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice 当 `approve` 更改或确认授权额度时触发。
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /**
     * 事件触发矩阵（约定）：
     * - Transfer：仅在 `_transfer`（from->to）、`_mint`（0->to）、`_burn`（from->0）内部触发。
     * - Approval：仅在 `_approve` 内触发；`_spendAllowance` 如需扣减，应通过 `_approve` 以便触发一次 Approval。
     * - 外部函数不直接 emit 事件。
     */

    // ---------------------- 自定义错误（建议统一使用） ----------------------
    error NotOwner();
    error ZeroAddress();
    error InsufficientBalance(uint256 balance, uint256 needed);
    error AllowanceExceeded(uint256 allowance, uint256 needed);
    error AllowanceOverflowed(uint256 allowance, uint256 needed);
    error TotalSupplyOverflowed();
    error PermitExpired(uint256 deadline);
    error InvalidSignature();

    // ---------------------- 修饰符（实现时可使用） ----------------------
    modifier onlyOwner() {
        if (msg.sender != _owner) revert NotOwner();
        _;
    }

    // ---------------------- 元数据（EIP-20 可选但本项目默认实现） ----------------------
    /// @notice 返回代币名称（实现时返回 `_name`）。
    function name() external view virtual returns (string memory) {
        return _name;
    }

    /// @notice 返回代币符号（实现时返回 `_symbol`）。
    function symbol() external view virtual returns (string memory) {
        return _symbol;
    }

    /// @notice 返回代币精度（V2 固定为 18，建议返回 `_DECIMALS`）。
    function decimals() external view virtual returns (uint8) {
        return _DECIMALS;
    }

    // ---------------------- EIP-20 必须函数（仅签名） ----------------------
    /// @notice 返回代币总供应量。
    function totalSupply() external view virtual returns (uint256) {
        return _totalSupply;
    }

    /// @notice 返回指定地址余额。
    function balanceOf(address owner) external view virtual returns (uint256) {
        return _balances[owner];
    }

    /// @notice 转账（0 数量视为正常转账并触发事件）。
    /// @dev 实现时：仅委托 `_transfer(msg.sender, to, value)` 并返回 true；
    ///      零地址/余额检查、事件与 hook 调用均在 `_transfer` 内部统一处理。
    function transfer(
        address to,
        uint256 value
    ) external virtual returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /// @notice 查询授权剩余额度。
    function allowance(
        address owner,
        address spender
    ) external view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    /// @notice 设定授权额度（重复调用覆盖旧值）。
    /// @dev 实现时：仅委托 `_approve(msg.sender, spender, value)` 并返回 true；
    ///      事件在 `_approve` 内触发，外部函数不直接 emit。
    function approve(
        address spender,
        uint256 value
    ) external virtual returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /// @notice 经授权从 `from` 转账给 `to`。
    /// @dev 实现时：先 `_spendAllowance(from, msg.sender, value)`（非无限授权时可能通过 `_approve` 触发一次 Approval），
    ///      再 `_transfer(from, to, value)`；外部函数不直接 emit 事件。
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external virtual returns (bool) {
        _spendAllowance(from, msg.sender, value);
        _transfer(from, to, value);
        return true;
    }

    // ---------------------- V2 扩展（仅签名） ----------------------
    /// @notice 增加授权额度（避免覆盖带来的竞态风险）。
    /// @dev 实现时：`new = current + addedValue`，通过 `_approve` 落库；
    ///      事件由 `_approve` 触发，外部函数不直接 emit。可选：为对称性加入溢出预检查（AllowanceOverflowed）。
    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external virtual returns (bool) {
        if (type(uint256).max - _allowances[msg.sender][spender] < addedValue)
            //一定程度上此处校验为伪需求
            revert AllowanceOverflowed(
                _allowances[msg.sender][spender],
                addedValue
            );
        uint256 newValue = _allowances[msg.sender][spender] + addedValue;
        _approve(msg.sender, spender, newValue);
        return true;
    }

    /// @notice 减少授权额度（不少于减少值）。
    /// @dev 实现时：检查 `current >= subtractedValue`，`new = current - subtractedValue`，通过 `_approve` 落库；
    ///      事件由 `_approve` 触发，外部函数不直接 emit。
    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external virtual returns (bool) {
        if (_allowances[msg.sender][spender] < subtractedValue)
            revert AllowanceExceeded(
                _allowances[msg.sender][spender],
                subtractedValue
            );
        uint256 newValue = _allowances[msg.sender][spender] - subtractedValue;
        _approve(msg.sender, spender, newValue);
        return true;
    }

    /// @notice 铸造代币，仅限约定权限方（owner/minter）。
    /// @dev 实现时：仅委托 `_mint(to, value)` 并返回 true；事件由 `_mint` 触发。
    function mint(
        address to,
        uint256 value
    ) public virtual onlyOwner returns (bool) {
        _mint(to, value);
        return true;
    }

    /// @notice 销毁调用者持有的代币。
    /// @dev 实现时：仅委托 `_burn(msg.sender, value)` 并返回 true；事件由 `_burn` 触发。
    function burn(uint256 value) public virtual returns (bool) {
        _burn(msg.sender, value);
        return true;
    }

    /// @notice 从 `from` 销毁代币（持有人或经授权者）。
    /// @dev 实现时：先 `_spendAllowance(from, msg.sender, value)`，再 `_burn(from, value)`；
    ///      事件由 `_burn` 触发，外部函数不直接 emit。
    function burnFrom(
        address from,
        uint256 value
    ) public virtual returns (bool) {
        _spendAllowance(from, msg.sender, value);
        _burn(from, value);
        return true;
    }

    // ---------------------- EIP-2612 Permit（仅签名） ----------------------
    /// @notice EIP-712 签名授权，成功后应触发 Approval(owner, spender, value)。
    /// @dev 实现时：`require(block.timestamp <= deadline)`；构造 EIP-712 `digest` 并用 `ecrecover` 校验；
    ///      `nonces[owner]++` 后调用 `_approve(owner, spender, value)`；事件由 `_approve` 触发；
    ///      域分隔符需考虑链 ID 变化（可复用 `DOMAIN_SEPARATOR` 或在链变更时重建）。
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual {
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

    /// @notice EIP-2612: 每个 owner 的 nonce。
    function nonces(address owner) external view virtual returns (uint256) {
        return _nonces[owner];
    }

    /// @notice EIP-2612/EIP-712: 域分隔符（实现需考虑链 ID 变化与 gas 取舍）。
    /// @dev 推荐“缓存 + 链 ID 变化时重算”模式：
    ///      - 构造中设置 `_INITIAL_CHAIN_ID=block.chainid` 与 `_DOMAIN_SEPARATOR=keccak256(abi.encode(EIP712Domain(...)))`；
    ///      - 若 `block.chainid==_INITIAL_CHAIN_ID` 直接返回缓存；否则用当前链 ID 现场重算后返回。
    ///      备选“动态计算”模式：不存储缓存，每次按 EIP-712 动态构造后返回（实现更简，gas 略高）。
    ///      注意：为减少后续 SLOAD，可将 name/version 的哈希设为 `immutable` 常量。
    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparator();
    }

    // ---------------------- 内部工具（EIP-712） ----------------------
    /// @notice 内部域分隔符函数，供 `permit` 等内部逻辑使用。
    /// @dev 实现策略：
    ///      1) 缓存 + 链 ID 变更时重算：
    ///         if (block.chainid == _INITIAL_CHAIN_ID) return _DOMAIN_SEPARATOR;
    ///         else return keccak256(abi.encode(
    ///             keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
    ///             keccak256(bytes(_name)),
    ///             keccak256(bytes(_version)),
    ///             block.chainid,
    ///             address(this)
    ///         ));
    ///      2) 每次动态计算：始终返回上述 keccak256(abi.encode(...)) 结果。
    ///      内部应调用本函数而非 external 的 `DOMAIN_SEPARATOR()`，以避免外部调用开销。
    function _domainSeparator() internal view virtual returns (bytes32) {
        // 占位返回，后续按上方注释替换为正式逻辑。
        return _DOMAIN_SEPARATOR;
    }

    // ---------------------- 内部核心（仅签名，供外部函数复用） ----------------------
    /// @dev 内部转账：要求 `from != address(0)` 且 `to != address(0)`；检查 `from` 余额；
    ///      在状态写入前调用 `_beforeTokenTransfer(from,to,amount)`；更新余额并 emit Transfer(from,to,amount)。
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        if (from == address(0)) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        if (_balances[from] < amount)
            revert InsufficientBalance(_balances[from], amount);

        _beforeTokenTransfer(from, to, amount);
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    /// @dev 内部授权：要求 `owner != address(0)`；写 `_allowances[owner][spender] = value` 并 emit Approval(owner,spender,value)。
    function _approve(
        address owner,
        address spender,
        uint256 value
    ) internal virtual {
        if (owner == address(0)) revert ZeroAddress();
        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /// @dev 内部消费授权：
    ///      - 若 `allowed == type(uint256).max` 视为无限授权：不扣减、不触发事件；
    ///      - 否则检查 `allowed >= amount`，扣减并通过 `_approve(owner, spender, newAllowed)` 触发一次 Approval。
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        if (_allowances[owner][spender] == type(uint256).max) return;
        if (_allowances[owner][spender] < amount)
            revert InsufficientBalance(_allowances[owner][spender], amount);
        _approve(owner, spender, _allowances[owner][spender] - amount);
    }

    /// @dev 内部铸造：检查 `to != address(0)`；在状态写入前调用 `_beforeTokenTransfer(address(0),to,amount)`；
    ///      更新 `_totalSupply` 与余额并 emit Transfer(address(0),to,amount)。
    function _mint(address to, uint256 amount) internal virtual {
        if (to == address(0)) revert ZeroAddress();
        if (type(uint256).max - _totalSupply < amount)
            revert TotalSupplyOverflowed();
        _beforeTokenTransfer(address(0), to, amount);
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    /// @dev 内部销毁：要求 `from != address(0)`；检查余额；在状态写入前调用 `_beforeTokenTransfer(from,address(0),amount)`；
    ///      更新 `_totalSupply` 与余额并 emit Transfer(from,address(0),amount)。
    function _burn(address from, uint256 amount) internal virtual {
        if (from == address(0)) revert ZeroAddress();
        if (_balances[from] < amount)
            revert InsufficientBalance(_balances[from], amount);
        _beforeTokenTransfer(from, address(0), amount);
        _totalSupply -= amount;
        _balances[from] -= amount;
        emit Transfer(from, address(0), amount);
    }

    /// @dev 预留钩子，转账/铸造/销毁前调用，默认空实现由子类覆盖。
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        //暂时空实现
    }
}
