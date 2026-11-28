// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Whitelist.sol";

contract WhitelistHiddenTest is Test {
    Whitelist public list;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA401);

    function setUp() public {
        list = new Whitelist();
    }

    function _three() internal view returns (address[] memory accounts) {
        accounts = new address[](3);
        accounts[0] = alice;
        accounts[1] = bob;
        accounts[2] = carol;
    }

    function testHiddenRepeatedAddAndRemoveAreNoOps() public {
        assertTrue(list.add(alice));
        assertFalse(list.add(alice));
        assertEq(list.allowedCount(), 1);

        assertFalse(list.remove(bob));
        assertEq(list.allowedCount(), 1);

        assertTrue(list.remove(alice));
        assertFalse(list.remove(alice));
        assertEq(list.allowedCount(), 0);
        assertFalse(list.remove(address(0)));
    }

    function testHiddenZeroAddressRejected() public {
        vm.expectRevert(Whitelist.ZeroAddress.selector);
        list.add(address(0));
        assertFalse(list.isAllowed(address(0)));
        assertEq(list.allowedCount(), 0);
    }

    function testHiddenBatchWithDuplicatesCountsOnce() public {
        list.add(bob);
        address[] memory accounts = new address[](5);
        accounts[0] = alice;
        accounts[1] = bob;
        accounts[2] = alice;
        accounts[3] = carol;
        accounts[4] = carol;
        assertEq(list.addBatch(accounts), 2);
        assertEq(list.allowedCount(), 3);

        assertEq(list.removeBatch(accounts), 3);
        assertEq(list.allowedCount(), 0);
        assertFalse(list.isAllowed(alice));
        assertFalse(list.isAllowed(bob));
        assertFalse(list.isAllowed(carol));
    }

    function testHiddenBatchWithZeroAddressIsAllOrNothing() public {
        address[] memory accounts = new address[](3);
        accounts[0] = alice;
        accounts[1] = bob;
        accounts[2] = address(0);
        vm.expectRevert(Whitelist.ZeroAddress.selector);
        list.addBatch(accounts);

        assertFalse(list.isAllowed(alice));
        assertFalse(list.isAllowed(bob));
        assertEq(list.allowedCount(), 0);
    }

    function testHiddenEmptyBatches() public {
        address[] memory none = new address[](0);
        assertEq(list.addBatch(none), 0);
        assertEq(list.removeBatch(none), 0);
        assertEq(list.allowedCount(), 0);
    }

    function testHiddenPartialRemoveBatch() public {
        list.addBatch(_three());
        address[] memory accounts = new address[](3);
        accounts[0] = bob;
        accounts[1] = address(0xDEAD);
        accounts[2] = address(0);
        assertEq(list.removeBatch(accounts), 1);
        assertEq(list.allowedCount(), 2);
        assertTrue(list.isAllowed(alice));
        assertFalse(list.isAllowed(bob));
        assertTrue(list.isAllowed(carol));
    }

    function testHiddenRemovalRevokesAccessButKeepsHistory() public {
        list.add(alice);
        vm.prank(alice);
        list.checkIn();

        list.remove(alice);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Whitelist.NotAllowed.selector, alice));
        list.checkIn();
        assertEq(list.checkIns(alice), 1);

        list.add(alice);
        vm.prank(alice);
        list.checkIn();
        assertEq(list.checkIns(alice), 2);
    }

    function testHiddenOwnerIsNotListedByDefault() public {
        assertFalse(list.isAllowed(address(this)));
        vm.expectRevert(abi.encodeWithSelector(Whitelist.NotAllowed.selector, address(this)));
        list.checkIn();

        list.add(address(this));
        list.checkIn();
        assertEq(list.checkIns(address(this)), 1);
    }

    function testHiddenOnlyOwnerManages() public {
        list.add(alice);
        address[] memory accounts = _three();

        // A listed address is still not the owner.
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Whitelist.NotOwner.selector, alice));
        list.add(bob);
        vm.expectRevert(abi.encodeWithSelector(Whitelist.NotOwner.selector, alice));
        list.remove(alice);
        vm.expectRevert(abi.encodeWithSelector(Whitelist.NotOwner.selector, alice));
        list.addBatch(accounts);
        vm.expectRevert(abi.encodeWithSelector(Whitelist.NotOwner.selector, alice));
        list.removeBatch(accounts);
        // The caller check comes before the zero-address check.
        vm.expectRevert(abi.encodeWithSelector(Whitelist.NotOwner.selector, alice));
        list.add(address(0));
        vm.stopPrank();

        assertEq(list.allowedCount(), 1);
        assertFalse(list.isAllowed(bob));
    }
}
