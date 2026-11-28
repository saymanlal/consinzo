// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TwoStepOwnable.sol";

contract TwoStepOwnableHiddenTest is Test {
    TwoStepOwnable public ownable;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA401);

    function setUp() public {
        ownable = new TwoStepOwnable();
    }

    function testHiddenZeroAddressCandidateRejected() public {
        vm.expectRevert(TwoStepOwnable.ZeroAddress.selector);
        ownable.proposeOwner(address(0));
        assertEq(ownable.pendingOwner(), address(0));
    }

    function testHiddenNonCandidateCannotAccept() public {
        ownable.proposeOwner(alice);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(TwoStepOwnable.NotPendingOwner.selector, bob));
        ownable.acceptOwnership();

        // The current owner is not the candidate either.
        vm.expectRevert(abi.encodeWithSelector(TwoStepOwnable.NotPendingOwner.selector, address(this)));
        ownable.acceptOwnership();

        assertEq(ownable.owner(), address(this));
        assertEq(ownable.pendingOwner(), alice);
    }

    function testHiddenAcceptWithNothingPending() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(TwoStepOwnable.NotPendingOwner.selector, alice));
        ownable.acceptOwnership();
    }

    function testHiddenPreviousOwnerLosesRights() public {
        ownable.proposeOwner(alice);
        vm.prank(alice);
        ownable.acceptOwnership();

        vm.expectRevert(abi.encodeWithSelector(TwoStepOwnable.NotOwner.selector, address(this)));
        ownable.proposeOwner(bob);

        vm.expectRevert(abi.encodeWithSelector(TwoStepOwnable.NotOwner.selector, address(this)));
        ownable.cancelProposal();

        // The new owner has full rights.
        vm.prank(alice);
        ownable.proposeOwner(bob);
        assertEq(ownable.pendingOwner(), bob);
    }

    function testHiddenNewProposalReplacesOld() public {
        ownable.proposeOwner(alice);
        ownable.proposeOwner(bob);
        assertEq(ownable.pendingOwner(), bob);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(TwoStepOwnable.NotPendingOwner.selector, alice));
        ownable.acceptOwnership();

        vm.prank(bob);
        ownable.acceptOwnership();
        assertEq(ownable.owner(), bob);
    }

    function testHiddenCancelRules() public {
        vm.expectRevert(TwoStepOwnable.NoPendingOwner.selector);
        ownable.cancelProposal();

        ownable.proposeOwner(alice);

        // The candidate cannot cancel; the caller check comes first.
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(TwoStepOwnable.NotOwner.selector, alice));
        ownable.cancelProposal();

        ownable.cancelProposal();
        vm.expectRevert(TwoStepOwnable.NoPendingOwner.selector);
        ownable.cancelProposal();

        // A stranger with nothing pending still gets the caller error.
        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(TwoStepOwnable.NotOwner.selector, carol));
        ownable.cancelProposal();
    }

    function testHiddenAcceptanceCannotBeReplayed() public {
        ownable.proposeOwner(alice);
        vm.prank(alice);
        ownable.acceptOwnership();

        // Alice hands over to Bob; her old acceptance must not work again.
        vm.prank(alice);
        ownable.proposeOwner(bob);
        vm.prank(bob);
        ownable.acceptOwnership();
        assertEq(ownable.owner(), bob);
        assertEq(ownable.pendingOwner(), address(0));

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(TwoStepOwnable.NotPendingOwner.selector, alice));
        ownable.acceptOwnership();
        assertEq(ownable.owner(), bob);
    }

    function testHiddenCallerCheckedBeforeZeroAddress() public {
        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(TwoStepOwnable.NotOwner.selector, carol));
        ownable.proposeOwner(address(0));
    }

    function testHiddenOwnerCanProposeSelfAndAccept() public {
        ownable.proposeOwner(address(this));
        ownable.acceptOwnership();
        assertEq(ownable.owner(), address(this));
        assertEq(ownable.pendingOwner(), address(0));
    }
}
