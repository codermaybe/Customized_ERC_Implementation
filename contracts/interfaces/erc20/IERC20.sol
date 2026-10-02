// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/// @title ERC-20 Token Standard
/// @dev See https://eips.ethereum.org/EIPS/eip-20
interface IERC20 {
    /// @dev MUST trigger when tokens are transferred, including zero value transfers.
    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    /// @dev MUST trigger on any successful call to `approve`.
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    /// @notice Returns the total token supply.
    function totalSupply() external view returns (uint256);

    /// @notice Returns the account balance of another account with address `_owner`.
    /// @param _owner The address from which the balance will be retrieved
    /// @return The balance of `_owner`
    function balanceOf(address _owner) external view returns (uint256);

    /// @notice Transfers `_value` amount of tokens to address `_to`.
    /// @dev Transfers of 0 values MUST be treated as normal transfers and fire `Transfer`.
    /// @param _to The receiver address
    /// @param _value The amount of tokens to transfer
    /// @return success True if the operation succeeded
    function transfer(address _to, uint256 _value) external returns (bool success);

    /// @notice Transfers `_value` amount of tokens from address `_from` to address `_to`.
    /// @dev Caller must have sufficient allowance from `_from`.
    /// @param _from The source address
    /// @param _to The receiver address
    /// @param _value The amount of tokens to transfer
    /// @return success True if the operation succeeded
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);

    /// @notice Allows `_spender` to withdraw from caller's account up to `_value`.
    /// @dev Repeated calls overwrite the current allowance with `_value`.
    /// @param _spender The address allowed to spend
    /// @param _value The allowance amount
    /// @return success True if the operation succeeded
    function approve(address _spender, uint256 _value) external returns (bool success);

    /// @notice Returns the amount which `_spender` is still allowed to withdraw from `_owner`.
    /// @param _owner The token owner
    /// @param _spender The approved spender
    /// @return remaining The remaining allowance
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);
}
