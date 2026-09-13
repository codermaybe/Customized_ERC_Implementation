pragma solidity ^0.8.28;

// https://eips.ethereum.org/EIPS/eip-777

interface ERC777TokensSender {
    function tokensToSend(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external;
}
