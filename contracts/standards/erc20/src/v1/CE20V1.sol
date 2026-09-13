// SPDX-License-Identifier: MIT

/**
 * @title CustomizedERC20
 * @author github.com/codermaybe
 * @dev CustomizedERC20 is a customized ERC20 token with a few additional features.
 * @dev 本合约仅用于学习和研究。所有复现均按照eip20标准。详见：https://github.com/ethereum/ercs/blob/master/ERCS/erc-20.md
 * @dev 自行复现的erc20各项功能。
 * @dev V1版本特性：1.除复现各标准函数外增加 _contractOwner字段，增加erc20未定义但常用方法 mint()、burn()。暂无增加角色地址池，特殊操作均有合约拥有者控制。
 */

pragma solidity ^0.8.28;

contract CE20V1 {
    address private _contractOwner; //自行设定，为合约拥有者
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) _allowances;
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 totalSupply
    ) {
        _contractOwner = msg.sender;
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
        _totalSupply = totalSupply;
        _balances[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    /*
    name
    Returns the name of the token - e.g. "MyToken".
    OPTIONAL - This method can be used to improve usability, but interfaces and other contracts MUST NOT expect these values to be present. */
    function name() public view returns (string memory) {
        return _name;
    }

    /*
    symbol
    Returns the symbol of the token. E.g. "HIX".
    OPTIONAL - This method can be used to improve usability, but interfaces and other contracts MUST NOT expect these values to be present. */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /*
    decimals
    Returns the number of decimals the token uses - e.g. 8, means to divide the token amount by 100000000 to get its user representation.
    OPTIONAL - This method can be used to improve usability, but interfaces and other contracts MUST NOT expect these values to be present.*/
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /*
    totalSupply
    Returns the total token supply.*/

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /*
    balanceOf
    Returns the account balance of another account with address _owner. */
    function balanceOf(address _owner) public view returns (uint256) {
        return _balances[_owner];
    }

    /*
    transfer
    Transfers _value amount of tokens to address _to, and MUST fire the Transfer event. 
    The function SHOULD throw if the message caller's account balance does not have enough tokens to spend.
    Note Transfers of 0 values MUST be treated as normal transfers and fire the Transfer event. */

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != address(0), unicode"不可向0地址转账");
        require(_balances[msg.sender] >= _value, unicode"余额不足");
        require(_balances[_to] + _value > _balances[_to], unicode"数值溢出");
        _balances[msg.sender] -= _value;
        _balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /*
    transferFrom
    Transfers _value amount of tokens from address _from to address _to, and MUST fire the Transfer event.
    The transferFrom method is used for a withdraw workflow, allowing contracts to transfer tokens on your behalf. 
    This can be used for example to allow a contract to transfer tokens on your behalf and/or to charge fees in sub-currencies. 
    The function SHOULD throw unless the _from account has deliberately authorized the sender of the message via some mechanism.
    Note Transfers of 0 values MUST be treated as normal transfers and fire the Transfer event. */
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool success) {
        require(_to != address(0), unicode"不可向0地址转账");
        require(
            _allowances[_from][msg.sender] >= _value,
            unicode"授权额度不足"
        );
        require(_balances[_from] >= _value, unicode"转账账户额度不足");
        require(_balances[_to] + _value > _balances[_to], unicode"余额溢出");
        _allowances[_from][msg.sender] -= _value;
        _balances[_from] -= _value;
        _balances[_to] += _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    /*
    approve
    Allows _spender to withdraw from your account multiple times, up to the _value amount. 
    If this function is called again it overwrites the current allowance with _value.
    NOTE: To prevent attack vectors like the one described here and discussed here, clients SHOULD make sure to create user interfaces in such a way that they set the allowance first to 0 before setting it to another value for the same spender. 
    THOUGH The contract itself shouldn't enforce it, to allow backwards compatibility with contracts deployed before */
    function approve(
        //此版本未解决重入攻击,安全版本可检查CE20V1_openzepplin.sol
        address _spender,
        uint256 _value
    ) public returns (bool success) {
        require(
            _allowances[msg.sender][_spender] + _value >
                _allowances[msg.sender][_spender],
            unicode"授权额度溢出"
        );
        require(_spender != address(0), unicode"转账地址为0");

        _allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /*
    allowance
    Returns the amount which _spender is still allowed to withdraw from _owner.*/
    function allowance(
        address _owner,
        address _spender
    ) public view returns (uint256 remaining) {
        return _allowances[_owner][_spender];
    }

    /*自定义方法实现，使用mint派生代币 */
    event Mint(address _to, uint256 _value);

    function mint(address _to, uint256 _value) public {
        require(
            msg.sender == _contractOwner,
            unicode"非合约拥有者无法派生代币"
        );
        require(_balances[_to] + _value > _balances[_to], unicode"余额溢出");
        require(_totalSupply + _value > _totalSupply, unicode"总代币量将溢出");
        _balances[_to] += _value;
        _totalSupply += _value;
        emit Transfer(address(0), _to, _value);
        emit Mint(_to, _value);
    }

    /*自定义方法实现，使用burn燃烧代币 */
    event Burn(address _from, uint256 _value);

    function burn(address _from, uint256 _value) public {
        require(
            msg.sender == _contractOwner,
            unicode"非合约拥有者无法派生代币"
        );
        require(
            _balances[_from] >= _value,
            unicode"检查燃烧的代币数量，超过用户余额"
        );
        _balances[_from] -= _value;
        _totalSupply -= _value;
        emit Burn(_from, _value);
    }
}
