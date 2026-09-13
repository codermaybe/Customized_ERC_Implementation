// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {CE721V3} from "contracts/standards/erc721/src/v3/CE721V3.sol";
import {CE721_OPV3} from "contracts/standards/erc721/src/v3/CE721_openzepplinV3.sol";

contract CE721V3Test is Test {
    CE721V3 internal token;
    CE721V3 internal implementation;
    CE721_OPV3 internal referenceToken;

    address internal owner = address(0xA11CE);
    address internal alice = address(0xBEEF);
    address internal bob = address(0xCAFE);
    address internal operator = address(0xD00D);

    function setUp() public {
        vm.startPrank(owner);

        implementation = new CE721V3();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            owner,
            abi.encodeCall(
                CE721V3.initialize,
                ("CE721V3", "CE721V3", "ipfs://collection/")
            )
        );
        token = CE721V3(address(proxy));

        CE721_OPV3 referenceImplementation = new CE721_OPV3();
        TransparentUpgradeableProxy referenceProxy = new TransparentUpgradeableProxy(
                address(referenceImplementation),
                owner,
                abi.encodeCall(
                    CE721_OPV3.initialize,
                    ("CE721_OPV3", "CE721_OPV3", owner)
                )
            );
        referenceToken = CE721_OPV3(address(referenceProxy));

        vm.stopPrank();
    }

    function test_initializeSetsMetadataOwnerAndInterfaces() public view {
        assertEq(token.name(), "CE721V3");
        assertEq(token.symbol(), "CE721V3");
        assertEq(token._contractOwner(), owner);
        assertEq(token.version(), "3");
        assertTrue(token.supportsInterface(0x01ffc9a7));
        assertTrue(token.supportsInterface(0x80ac58cd));
        assertTrue(token.supportsInterface(0x5b5e139f));
    }

    function test_implementationCannotBeInitialized() public {
        vm.expectRevert(CE721V3.AlreadyInitialized.selector);
        implementation.initialize("Hijacked", "BAD", "bad://");
    }

    function test_mintTransferApproveAndBurn() public {
        vm.prank(owner);
        token.mint(alice, 7);
        assertEq(token.ownerOf(7), alice);
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.tokenURI(7), "ipfs://collection/7");

        vm.prank(alice);
        token.approve(operator, 7);
        assertEq(token.getApproved(7), operator);

        vm.prank(operator);
        token.transferFrom(alice, bob, 7);
        assertEq(token.ownerOf(7), bob);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 1);
        assertEq(token.getApproved(7), address(0));

        vm.prank(bob);
        token.burn(7);
        vm.expectRevert(
            abi.encodeWithSelector(CE721V3.TokenNotExists.selector, 7)
        );
        token.ownerOf(7);
    }

    function test_coreOwnershipFlowMatchesReference() public {
        vm.startPrank(owner);
        token.mint(alice, 1);
        referenceToken.mint(alice, 1);
        vm.stopPrank();

        vm.startPrank(alice);
        token.transferFrom(alice, bob, 1);
        referenceToken.transferFrom(alice, bob, 1);
        vm.stopPrank();

        assertEq(token.ownerOf(1), referenceToken.ownerOf(1));
        assertEq(token.balanceOf(alice), referenceToken.balanceOf(alice));
        assertEq(token.balanceOf(bob), referenceToken.balanceOf(bob));
    }

    function test_onlyOwnerCanMint() public {
        vm.prank(alice);
        vm.expectRevert(CE721V3.NotOwner.selector);
        token.mint(alice, 1);
    }

    function test_setBaseURIChangesTokenURI() public {
        vm.prank(owner);
        token.mint(alice, 12);

        vm.prank(owner);
        token.setBaseURI("https://example.test/token/");
        assertEq(token.tokenURI(12), "https://example.test/token/12");
    }
}
