// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {CE20V1} from "contracts/CustomizedERC20/v1/CE20V1.sol";

contract CE20V1Test is Test {
    CE20V1 token;
    address owner = address(this);
    address addr1 = address(0xA11CE);
    address addr2 = address(0xB0B);

    function setUp() public {
        token = new CE20V1("CE20V1", "CE20V1", 18, 1_000 ether);
    }

    // Deployment
    function test_deploy_ownerHasInitialSupply() public {
        assertEq(token.balanceOf(owner), 1_000 ether);
    }

    function test_totalSupply_equals_ownerBalance() public {
        assertEq(token.totalSupply(), token.balanceOf(owner));
    }

    // Transfers
    function test_transfer_betweenAccounts() public {
        token.transfer(addr1, 50 ether);
        assertEq(token.balanceOf(addr1), 50 ether);

        vm.prank(addr1);
        token.transfer(addr2, 50 ether);
        assertEq(token.balanceOf(addr2), 50 ether);
    }

    function test_transfer_reverts_whenInsufficientBalance() public {
        uint256 initialOwnerBal = token.balanceOf(owner);
        vm.prank(addr1);
        vm.expectRevert(bytes(unicode"余额不足"));
        token.transfer(owner, 1 ether);
        assertEq(token.balanceOf(owner), initialOwnerBal);
    }

    function test_approve_updatesAllowance() public {
        token.approve(addr1, 100 ether);
        assertEq(token.allowance(owner, addr1), 100 ether);
    }

    function test_transferFrom_usesAllowance() public {
        token.approve(addr1, 100 ether);
        vm.prank(addr1);
        token.transferFrom(owner, addr2, 50 ether);
        assertEq(token.balanceOf(addr2), 50 ether);
    }

    function test_transferFrom_reverts_whenExceedsAllowance() public {
        token.approve(addr1, 50 ether);
        vm.prank(addr1);
        vm.expectRevert(bytes(unicode"授权额度不足"));
        token.transferFrom(owner, addr2, 100 ether);
    }

    // Minting
    function test_mint_byOwner() public {
        token.mint(addr1, 100 ether);
        assertEq(token.balanceOf(addr1), 100 ether);
        assertEq(token.totalSupply(), 1_100 ether);
    }

    function test_mint_reverts_whenNotOwner() public {
        vm.prank(addr1);
        vm.expectRevert(bytes(unicode"非合约拥有者无法派生代币"));
        token.mint(addr1, 100 ether);
    }

    // Burning
    function test_burn_byOwner() public {
        token.burn(owner, 100 ether);
        assertEq(token.balanceOf(owner), 900 ether);
        assertEq(token.totalSupply(), 900 ether);
    }

    function test_burn_reverts_whenNotOwner() public {
        vm.prank(addr1);
        vm.expectRevert(bytes(unicode"非合约拥有者无法派生代币"));
        token.burn(owner, 100 ether);
    }
}

