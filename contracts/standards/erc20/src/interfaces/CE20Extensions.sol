// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/// @title CE20 allowance extension
/// @dev Project extension, not part of the ERC-20 core standard.
interface CE20AllowanceExtensions {
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
}

/// @title CE20 mint and burn extension
/// @dev Project extension, not part of the ERC-20 core standard.
interface CE20MintBurn {
    function mint(address to, uint256 value) external returns (bool);

    function burn(uint256 value) external returns (bool);

    function burnFrom(address from, uint256 value) external returns (bool);
}

/// @title CE20 permit extension
/// @dev EIP-2612 style permit extension used by this project.
interface CE20Permit {
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;

    function nonces(address owner) external view returns (uint256);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
