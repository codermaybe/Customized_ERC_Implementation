// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {CE20V3} from "contracts/standards/erc20/src/v3/CE20V3.sol";
import {CE20V3_OpenZeppelin} from "contracts/standards/erc20/src/v3/CE20V3_OpenZeppelin.sol";

contract CE20V3UpgradeMock is CE20V3 {
    function upgradeMarker() external pure returns (uint256) {
        return 4;
    }
}

contract CE20V3Test is Test {
    event Transfer(address indexed from, address indexed to, uint256 value);

    CE20V3 internal token;
    CE20V3 internal implementation;
    CE20V3_OpenZeppelin internal referenceToken;

    address internal owner = address(0xA11CE);
    address internal alice = address(0xBEEF);
    address internal bob = address(0xCAFE);
    address internal spender = address(0xD00D);
    address internal newOwner = address(0xABCD);

    bytes32 internal constant ERC1967_ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function setUp() public {
        vm.startPrank(owner);

        implementation = new CE20V3();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation), owner, abi.encodeCall(CE20V3.initialize, ("CE20V3", "CE20V3"))
        );
        token = CE20V3(address(proxy));

        CE20V3_OpenZeppelin referenceImplementation = new CE20V3_OpenZeppelin();
        TransparentUpgradeableProxy referenceProxy = new TransparentUpgradeableProxy(
            address(referenceImplementation),
            owner,
            abi.encodeCall(CE20V3_OpenZeppelin.initialize, ("CE20V3_OpenZeppelin", "CE20V3_OpenZeppelin", owner))
        );
        referenceToken = CE20V3_OpenZeppelin(address(referenceProxy));

        vm.stopPrank();
    }

    function test_initialize_setsMetadataOwnerAndSupply() public view {
        assertEq(token.name(), "CE20V3");
        assertEq(token.symbol(), "CE20V3");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
        assertEq(token._contractOwner(), owner);
        assertEq(token.version(), "3");
    }

    function test_implementationCannotBeInitialized() public {
        vm.expectRevert(CE20V3.AlreadyInitialized.selector);
        implementation.initialize("Hijacked", "BAD");
    }

    function test_initialize_revertsWhenCalledTwice() public {
        vm.expectRevert(CE20V3.AlreadyInitialized.selector);
        token.initialize("Again", "AGN");
    }

    function test_mintTransferAndBurnMatchReference() public {
        vm.startPrank(owner);
        assertTrue(token.mint(alice, 100));
        assertTrue(referenceToken.mint(alice, 100));
        vm.stopPrank();

        vm.startPrank(alice);
        assertTrue(token.transfer(bob, 40));
        assertTrue(referenceToken.transfer(bob, 40));
        vm.stopPrank();

        vm.startPrank(bob);
        assertTrue(token.burn(10));
        assertTrue(referenceToken.burn(10));
        vm.stopPrank();

        assertEq(token.balanceOf(alice), referenceToken.balanceOf(alice));
        assertEq(token.balanceOf(bob), referenceToken.balanceOf(bob));
        assertEq(token.totalSupply(), referenceToken.totalSupply());
    }

    function test_nonOwnerMint_reverts() public {
        vm.prank(alice);
        vm.expectRevert(CE20V3.NotOwner.selector);
        token.mint(alice, 1);
    }

    function test_transferToZero_reverts() public {
        vm.prank(owner);
        token.mint(alice, 1);

        vm.prank(alice);
        vm.expectRevert(CE20V3.ZeroAddress.selector);
        token.transfer(address(0), 1);
    }

    function test_zeroTransfer_emitsTransfer() public {
        vm.prank(owner);
        token.mint(alice, 1);

        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(alice, bob, 0);

        vm.prank(alice);
        assertTrue(token.transfer(bob, 0));
    }

    function test_approveTransferFromAndBurnFrom() public {
        vm.prank(owner);
        token.mint(alice, 100);

        vm.prank(alice);
        assertTrue(token.approve(spender, 60));

        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, 10));

        vm.prank(spender);
        assertTrue(token.burnFrom(alice, 20));

        assertEq(token.balanceOf(alice), 70);
        assertEq(token.balanceOf(bob), 10);
        assertEq(token.totalSupply(), 80);
        assertEq(token.allowance(alice, spender), 30);
    }

    function test_infiniteAllowanceDoesNotDecrease() public {
        vm.prank(owner);
        token.mint(alice, 10);

        vm.prank(alice);
        token.approve(spender, type(uint256).max);

        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, 1));

        assertEq(token.allowance(alice, spender), type(uint256).max);
    }

    function test_permitSetsAllowanceAndConsumesNonce() public {
        (address permitOwner, uint256 privateKey) = makeAddrAndKey("permitOwner");
        uint256 value = 42;
        uint256 deadline = block.timestamp + 1 days;
        bytes32 permitTypehash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash =
            keccak256(abi.encode(permitTypehash, permitOwner, spender, value, token.nonces(permitOwner), deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        token.permit(permitOwner, spender, value, deadline, v, r, s);

        assertEq(token.allowance(permitOwner, spender), value);
        assertEq(token.nonces(permitOwner), 1);

        vm.expectRevert(CE20V3.InvalidSignature.selector);
        token.permit(permitOwner, spender, value, deadline, v, r, s);
        assertEq(token.nonces(permitOwner), 1);
    }

    function test_permitRejectsInvalidVWithoutConsumingNonce() public {
        vm.expectRevert(abi.encodeWithSelector(CE20V3.InvalidSignatureV.selector, 1));
        token.permit(alice, spender, 1, block.timestamp, 1, bytes32(0), bytes32(0));
        assertEq(token.nonces(alice), 0);
    }

    function test_domainSeparatorChangesWithChainId() public {
        bytes32 originalDomainSeparator = token.DOMAIN_SEPARATOR();
        vm.chainId(block.chainid + 1);
        assertNotEq(token.DOMAIN_SEPARATOR(), originalDomainSeparator);
    }

    function test_twoStepOwnershipTransfer() public {
        vm.prank(owner);
        token.transferOwnership(newOwner);
        assertEq(token._pendingOwner(), newOwner);

        vm.prank(newOwner);
        token.acceptOwnership();

        assertEq(token._contractOwner(), newOwner);
        assertEq(token._pendingOwner(), address(0));
        vm.prank(newOwner);
        assertTrue(token.mint(alice, 1));
    }

    function test_upgradePreservesV3State() public {
        vm.startPrank(owner);
        token.mint(alice, 100);
        token.transferOwnership(newOwner);
        vm.stopPrank();

        vm.prank(alice);
        token.approve(spender, 25);

        CE20V3UpgradeMock nextImplementation = new CE20V3UpgradeMock();
        address proxyAdminAddress = address(uint160(uint256(vm.load(address(token), ERC1967_ADMIN_SLOT))));

        vm.prank(owner);
        ProxyAdmin(proxyAdminAddress)
            .upgradeAndCall(ITransparentUpgradeableProxy(address(token)), address(nextImplementation), bytes(""));

        CE20V3UpgradeMock upgraded = CE20V3UpgradeMock(address(token));
        assertEq(upgraded.upgradeMarker(), 4);
        assertEq(upgraded.name(), "CE20V3");
        assertEq(upgraded.symbol(), "CE20V3");
        assertEq(upgraded._contractOwner(), owner);
        assertEq(upgraded._pendingOwner(), newOwner);
        assertEq(upgraded.balanceOf(alice), 100);
        assertEq(upgraded.totalSupply(), 100);
        assertEq(upgraded.allowance(alice, spender), 25);
    }
}
