// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {CE1155V2} from "contracts/standards/erc1155/src/v2/CE1155V2.sol";

contract Mock1155Receiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return bytes4(
            keccak256("onERC1155Received(address,address,uint256,uint256,bytes)")
        );
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return bytes4(
            keccak256(
                "onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"
            )
        );
    }
}

contract Bad1155Receiver {}

contract CE1155V2Test is Test {
    CE1155V2 token;

    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address operator = address(0xD00D);

    uint256 FT_ID = 1001;
    uint256 NFT_ID = 2001;

    function setUp() public {
        token = new CE1155V2("THE OASIS", "OASIS", "ipfs://base/");

        token.createItemType(FT_ID, "gold_coin", "", false);
        token.createItemType(NFT_ID, "final_key", "", true);
    }

    function test_metadata_and_uri() public {
        assertEq(token.name(), "THE OASIS");
        assertEq(token.symbol(), "OASIS");
        assertEq(token.uri(FT_ID), "ipfs://base/1001");

        token.setBaseURI("ipfs://new/");
        assertEq(token.uri(FT_ID), "ipfs://new/1001");

        token.updateItemType(FT_ID, "gold_coin", "ipfs://item/1001.json", false);
        assertEq(token.uri(FT_ID), "ipfs://item/1001.json");
    }

    function test_mint_ft_and_transfer() public {
        token.mint(alice, FT_ID, 100, "");
        assertEq(token.balanceOf(alice, FT_ID), 100);

        vm.prank(alice);
        token.safeTransferFrom(alice, bob, FT_ID, 40, "");

        assertEq(token.balanceOf(alice, FT_ID), 60);
        assertEq(token.balanceOf(bob, FT_ID), 40);
    }

    function test_mint_nft_enforces_single_supply() public {
        token.mint(alice, NFT_ID, 1, "");
        assertEq(token.balanceOf(alice, NFT_ID), 1);

        vm.expectRevert(
            abi.encodeWithSelector(CE1155V2.NFTAlreadyAssigned.selector, NFT_ID)
        );
        token.mint(bob, NFT_ID, 1, "");

        vm.expectRevert(CE1155V2.NFTAmountInvalid.selector);
        token.mint(bob, NFT_ID, 2, "");
    }

    function test_single_allowance_flow() public {
        token.mint(alice, FT_ID, 10, "");

        vm.prank(alice);
        token.setApprovalForSingle(operator, FT_ID, 6);

        vm.prank(operator);
        token.safeTransferFrom(alice, bob, FT_ID, 4, "");

        assertEq(token.balanceOf(alice, FT_ID), 6);
        assertEq(token.balanceOf(bob, FT_ID), 4);

        vm.prank(operator);
        vm.expectRevert();
        token.safeTransferFrom(alice, bob, FT_ID, 3, "");
    }

    function test_setApprovalForAll_flow() public {
        token.mint(alice, FT_ID, 30, "");

        vm.prank(alice);
        token.setApprovalForAll(operator, true);

        vm.prank(operator);
        token.safeTransferFrom(alice, bob, FT_ID, 11, "");

        assertEq(token.balanceOf(alice, FT_ID), 19);
        assertEq(token.balanceOf(bob, FT_ID), 11);
    }

    function test_safe_transfer_to_good_and_bad_receiver() public {
        token.mint(alice, FT_ID, 5, "");

        Mock1155Receiver good = new Mock1155Receiver();
        vm.prank(alice);
        token.safeTransferFrom(alice, address(good), FT_ID, 2, "");
        assertEq(token.balanceOf(address(good), FT_ID), 2);

        Bad1155Receiver bad = new Bad1155Receiver();
        vm.prank(alice);
        vm.expectRevert(CE1155V2.InvalidReceiver.selector);
        token.safeTransferFrom(alice, address(bad), FT_ID, 1, "");
    }

    function test_batch_transfer() public {
        token.mint(alice, FT_ID, 50, "");
        token.mint(alice, NFT_ID, 1, "");

        uint256[] memory ids = new uint256[](2);
        ids[0] = FT_ID;
        ids[1] = NFT_ID;

        uint256[] memory values = new uint256[](2);
        values[0] = 8;
        values[1] = 1;

        vm.prank(alice);
        token.safeBatchTransferFrom(alice, bob, ids, values, "");

        assertEq(token.balanceOf(alice, FT_ID), 42);
        assertEq(token.balanceOf(bob, FT_ID), 8);
        assertEq(token.balanceOf(alice, NFT_ID), 0);
        assertEq(token.balanceOf(bob, NFT_ID), 1);
    }

    function test_burn_and_burnBatch() public {
        token.mint(alice, FT_ID, 20, "");
        token.mint(alice, NFT_ID, 1, "");

        vm.prank(alice);
        token.burn(alice, FT_ID, 5);
        assertEq(token.balanceOf(alice, FT_ID), 15);

        uint256[] memory ids = new uint256[](2);
        ids[0] = FT_ID;
        ids[1] = NFT_ID;

        uint256[] memory values = new uint256[](2);
        values[0] = 3;
        values[1] = 1;

        vm.prank(alice);
        token.burnBatch(alice, ids, values);

        assertEq(token.balanceOf(alice, FT_ID), 12);
        assertEq(token.balanceOf(alice, NFT_ID), 0);
    }

    function test_two_step_ownership() public {
        token.transferOwnership(alice);

        vm.prank(alice);
        token.acceptOwnership();

        vm.expectRevert(CE1155V2.NotOwner.selector);
        token.createItemType(3001, "x", "", false);

        vm.prank(alice);
        token.createItemType(3001, "x", "", false);
    }

    function test_update_type_reject_when_nft_owned() public {
        token.mint(alice, NFT_ID, 1, "");
        vm.expectRevert(
            abi.encodeWithSelector(CE1155V2.NFTTypeChangeBlocked.selector, NFT_ID)
        );
        token.updateItemType(NFT_ID, "final_key", "", false);
    }

    function test_setApprovalForSingle_zero_operator_reverts() public {
        token.mint(alice, FT_ID, 1, "");
        vm.prank(alice);
        vm.expectRevert(CE1155V2.InvalidOperator.selector);
        token.setApprovalForSingle(address(0), FT_ID, 1);
    }

    function test_safeBatch_length_mismatch_reverts() public {
        token.mint(alice, FT_ID, 2, "");

        uint256[] memory ids = new uint256[](1);
        ids[0] = FT_ID;

        uint256[] memory values = new uint256[](2);
        values[0] = 1;
        values[1] = 1;

        vm.prank(alice);
        vm.expectRevert(CE1155V2.LengthMismatch.selector);
        token.safeBatchTransferFrom(alice, bob, ids, values, "");
    }
}
