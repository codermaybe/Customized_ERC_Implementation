// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/// @title ERC-20 Token Standard, optional metadata extension
/// @dev See https://eips.ethereum.org/EIPS/eip-20
interface ERC20Metadata {
    /// @notice Returns the name of the token.
    function name() external view returns (string memory);

    /// @notice Returns the symbol of the token.
    function symbol() external view returns (string memory);

    /// @notice Returns the number of decimals the token uses.
    function decimals() external view returns (uint8);
}
