// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {CE20_OPV1} from "contracts/CustomizedERC20/v1/CE20_openzepplinV1.sol";

contract CE20_OPV1Test is Test {
    CE20_OPV1 token;
    address owner = address(this);
    address addr1 = address(0xA11CE);
    address addr2 = address(0xB0B);

    // mirror events for expectEmit
    event Mint(address _to, uint256 _value);
    event Burn(address _from, uint256 _value);

    function setUp() public {
        token = new CE20_OPV1(1_000 ether);
    }

    // Deployment
    function test_deploy_initialSupplyAssignedToOwner() public {
        assertEq(token.balanceOf(owner), 1_000 ether);
    }

    function test_metadata_name_symbol() public {
        assertEq(token.name(), "CE20_OPV1");
        assertEq(token.symbol(), "CE20_OPV1");
    }

    function test_owner_is_deployer() public {
        assertEq(token.owner(), owner);
    }

    // Mint
    function test_owner_can_mint_with_event() public {
        vm.expectEmit(true, false, false, true, address(token));
        emit Mint(addr1, 500 ether);
        token.mint(addr1, 500 ether);
        assertEq(token.balanceOf(addr1), 500 ether);
    }

    function test_nonOwner_mint_reverts_customError() public {
        vm.prank(addr1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, addr1));
        token.mint(addr1, 500 ether);
    }

    // Burn
    function test_owner_can_burn_with_event() public {
        // ensure addr1 has balance
        token.mint(addr1, 200 ether);
        uint256 beforeBal = token.balanceOf(addr1);
        vm.expectEmit(true, false, false, true, address(token));
        emit Burn(addr1, 200 ether);
        token.burn(addr1, 200 ether);
        assertEq(token.balanceOf(addr1), beforeBal - 200 ether);
    }

    function test_burn_more_than_balance_reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                addr1,
                0,
                type(uint256).max
            )
        );
        token.burn(addr1, type(uint256).max);
    }

    function test_nonOwner_burn_reverts_customError() public {
        vm.prank(addr1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, addr1));
        token.burn(owner, 100 ether);
    }

    // ERC20 standard flows
    function test_transfer_between_accounts() public {
        uint256 amount = 100 ether;
        token.transfer(addr1, amount);
        assertEq(token.balanceOf(addr1), amount);

        vm.prank(addr1);
        token.transfer(addr2, amount);
        assertEq(token.balanceOf(addr2), amount);
    }

    function test_transfer_insufficient_balance_reverts() public {
        uint256 invalid = 10_000 ether;
        vm.prank(addr2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                addr2,
                0,
                invalid
            )
        );
        token.transfer(owner, invalid);
    }

    function test_approve_updates_allowance() public {
        uint256 approveAmount = 50 ether;
        vm.prank(owner);
        token.approve(addr1, approveAmount);
        assertEq(token.allowance(owner, addr1), approveAmount);
    }

    // Ownership
    function test_transferOwnership_and_newOwnerMint() public {
        // clear balances of addr1/addr2 if any
        uint256 b1 = token.balanceOf(addr1);
        if (b1 > 0) token.burn(addr1, b1);
        uint256 b2 = token.balanceOf(addr2);
        if (b2 > 0) token.burn(addr2, b2);

        token.transferOwnership(addr1);
        assertEq(token.owner(), addr1);

        vm.prank(addr1);
        token.mint(addr2, 500 ether);
        assertEq(token.balanceOf(addr2), 500 ether);
    }
}
