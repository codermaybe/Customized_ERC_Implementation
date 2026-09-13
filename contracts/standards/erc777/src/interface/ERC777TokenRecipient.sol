pragma solidity ^0.8.28;

// https://eips.ethereum.org/EIPS/eip-777

interface ERC777TokensRecipient {
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external;
}
