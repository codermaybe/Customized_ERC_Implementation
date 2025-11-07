// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2 as console} from "forge-std/Test.sol";
import {CE721V2} from "contracts/CustomizedERC721/v2/CE721V2.sol";

contract GoodReceiver {
    function onERC721Received(
        address /*operator*/,
        address /*from*/,
        uint256 /*tokenId*/,
        bytes memory /*data*/
    ) external pure returns (bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}

contract BadReceiver {}

contract CE721V2Test is Test {
    CE721V2 nft;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        nft = new CE721V2("Test721", "T721", "ipfs://base/");
    }

    function test_supportsInterface() public {
        assertTrue(nft.supportsInterface(0x01ffc9a7)); // ERC165
        assertTrue(nft.supportsInterface(0x80ac58cd)); // ERC721
        assertTrue(nft.supportsInterface(0x5b5e139f)); // Metadata
    }

    function test_mint_and_tokenURI() public {
        nft.mint(alice, 0);
        assertEq(nft.balanceOf(alice), 1);
        vm.prank(alice);
        assertEq(nft.ownerOf(0), alice);
        // tokenURI
        string memory uri = nft.tokenURI(0);
        assertEq(uri, string(abi.encodePacked("ipfs://base/", "0")));
    }

    function test_safeMint_good_receiver() public {
        GoodReceiver gr = new GoodReceiver();
        nft.safeMint(address(gr), 1, bytes(""));
        assertEq(nft.ownerOf(1), address(gr));
    }

    function test_safeMint_bad_receiver_reverts() public {
        BadReceiver br = new BadReceiver();
        vm.expectRevert();
        nft.safeMint(address(br), 2, bytes(""));
    }

    function test_approve_and_transferFrom() public {
        nft.mint(alice, 3);
        vm.prank(alice);
        nft.approve(address(this), 3);
        nft.transferFrom(alice, bob, 3);
        assertEq(nft.ownerOf(3), bob);
        assertEq(nft.getApproved(3), address(0)); // cleared
    }

    function test_setApprovalForAll_operator_transfer() public {
        nft.mint(alice, 4);
        vm.prank(alice);
        nft.setApprovalForAll(address(this), true);
        nft.transferFrom(alice, bob, 4);
        assertEq(nft.ownerOf(4), bob);
    }

    function test_burn_by_owner_and_contractOwner() public {
        // burn by token owner
        nft.mint(alice, 5);
        vm.prank(alice);
        nft.burn(5);
        vm.expectRevert();
        nft.ownerOf(5);

        // burn by contract owner
        nft.mint(alice, 6);
        nft.burn(6); // msg.sender is contract owner
        vm.expectRevert();
        nft.ownerOf(6);
    }

    function test_two_step_ownership_transfer() public {
        // contract owner is address(this)
        nft.transferOwnership(alice);
        // accept by alice
        vm.prank(alice);
        nft.acceptOwnership();
        // after ownership transfer, only alice can mint
        vm.expectRevert();
        nft.mint(bob, 7);
        vm.prank(alice);
        nft.mint(bob, 7);
        assertEq(nft.ownerOf(7), bob);
    }

    function test_getApproved_nonexistent_reverts() public {
        vm.expectRevert();
        nft.getApproved(999);
    }

    function test_balanceOf_zero_address_reverts() public {
        vm.expectRevert();
        nft.balanceOf(address(0));
    }

    function test_mintNext_increments() public {
        uint256 id0 = nft.mintNext(alice);
        uint256 id1 = nft.mintNext(alice);
        assertEq(id1, id0 + 1);
        assertEq(nft.ownerOf(id0), alice);
        assertEq(nft.ownerOf(id1), alice);
    }
}
