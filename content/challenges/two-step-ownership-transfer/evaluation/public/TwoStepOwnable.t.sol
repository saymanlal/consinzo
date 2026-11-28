// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TwoStepOwnable.sol";

contract TwoStepOwnableTest is Test {
    TwoStepOwnable public ownable;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        ownable = new TwoStepOwnable();
    }

    function testInitialOwner() public view {
        assertEq(ownable.owner(), address(this));
        assertEq(ownable.pendingOwner(), address(0));
    }

    function testProposeDoesNotTransfer() public {
        ownable.proposeOwner(alice);
        assertEq(ownable.owner(), address(this));
        assertEq(ownable.pendingOwner(), alice);
    }

    function testAcceptTransfersOwnership() public {
        ownable.proposeOwner(alice);
        vm.prank(alice);
        ownable.acceptOwnership();
        assertEq(ownable.owner(), alice);
        assertEq(ownable.pendingOwner(), address(0));
    }

    function testOnlyOwnerCanPropose() public {
        vm.prank(alice);
        vm.expectRevert(TwoStepOwnable.NotOwner.selector);
        ownable.proposeOwner(alice);
    }

    function testCancelProposal() public {
        ownable.proposeOwner(alice);
        ownable.cancelProposal();
        assertEq(ownable.pendingOwner(), address(0));

        vm.prank(alice);
        vm.expectRevert(TwoStepOwnable.NotPendingOwner.selector);
        ownable.acceptOwnership();
    }
}
