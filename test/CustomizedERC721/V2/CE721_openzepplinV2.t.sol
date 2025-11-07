// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {CE721_OPV2} from "contracts/CustomizedERC721/v2/CE721_openzepplinV2.sol";

contract MockReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external pure returns (bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}

contract Dummy {}

contract CE721_OPV2_Test is Test {
    CE721_OPV2 nft;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        nft = new CE721_OPV2("OpenZ721", "OZ721", address(this));
    }

    function test_supportsInterface() public {
        assertTrue(nft.supportsInterface(0x01ffc9a7)); // ERC165
        assertTrue(nft.supportsInterface(0x80ac58cd)); // ERC721
        assertTrue(nft.supportsInterface(0x5b5e139f)); // Metadata
    }

    function test_balanceOf_zero_address_reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(IERC721Errors.ERC721InvalidOwner.selector, address(0))
        );
        nft.balanceOf(address(0));
    }

    function test_getApproved_nonexistent_reverts() public {
        vm.expectRevert(); // OZ v5: ERC721NonexistentToken(tokenId)
        nft.getApproved(999);
    }

    function test_two_step_ownership_transfer() public {
        nft.transferOwnership(alice);
        vm.prank(alice);
        nft.acceptOwnership();
        // now only alice can mint
        vm.expectRevert();
        nft.mint(bob, 1);
        vm.prank(alice);
        nft.mint(bob, 1);
        assertEq(nft.ownerOf(1), bob);
        // cancel path: alice initiates then cancels
        vm.prank(alice);
        nft.transferOwnership(address(this));
        vm.prank(alice);
        nft.cancelOwnershipTransfer();
        vm.expectRevert();
        nft.acceptOwnership(); // cancelled, no pending owner
    }

    function test_safeMint_and_tokenURI() public {
        MockReceiver mr = new MockReceiver();
        vm.prank(address(this));
        nft.safeMint(address(mr), 10, "ipfs://u/10");
        assertEq(nft.ownerOf(10), address(mr));
        // tokenURI is readable when transferred to EOA later
        // transfer out to alice
        // Need operator as current owner is contract address (mr), simulate via receiver not exposing transfer.
        // Mint directly to alice with URI
        nft.safeMint(alice, 11, "ipfs://u/11");
        vm.prank(alice);
        assertEq(nft.tokenURI(11), "ipfs://u/11");
    }

    function test_safeMint_bad_receiver_reverts() public {
        Dummy bad = new Dummy();
        vm.expectRevert(
            abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(bad))
        );
        nft.safeMint(address(bad), 12);
    }

    function test_safeMint_good_receiver() public {
        MockReceiver mr = new MockReceiver();
        nft.safeMint(address(mr), 13);
        assertEq(nft.ownerOf(13), address(mr));
    }

    function test_mintNext_increments() public {
        uint256 id0 = nft.mintNext(alice);
        uint256 id1 = nft.mintNext(alice);
        assertEq(id1, id0 + 1);
    }

    function test_burn() public {
        nft.mint(alice, 100);
        vm.prank(alice);
        nft.burn(100);
        vm.expectRevert();
        nft.ownerOf(100);
    }

    function test_approve_and_transferFrom() public {
        nft.mint(alice, 21);
        vm.prank(alice);
        nft.approve(address(this), 21);
        nft.transferFrom(alice, bob, 21);
        assertEq(nft.ownerOf(21), bob);
        // approval cleared -> returns address(0) in OZ v5
        address approved = nft.getApproved(21);
        assertEq(approved, address(0));
    }

    function test_setApprovalForAll_operator_transfer() public {
        nft.mint(alice, 22);
        vm.prank(alice);
        nft.setApprovalForAll(address(this), true);
        nft.transferFrom(alice, bob, 22);
        assertEq(nft.ownerOf(22), bob);
    }
}
