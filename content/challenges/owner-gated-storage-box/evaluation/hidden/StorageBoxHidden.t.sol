// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StorageBox.sol";

contract StorageBoxHiddenTest is Test {
    StorageBox public box;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        box = new StorageBox(5);
    }

    function testHiddenRevertCarriesCaller() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(StorageBox.NotOwner.selector, bob));
        box.set(1);
    }

    function testHiddenFailedWriteChangesNothing() public {
        box.set(11);
        vm.prank(alice);
        vm.expectRevert();
        box.set(12);
        assertEq(box.get(), 11);
        assertEq(box.updateCount(), 1);
    }

    function testHiddenEverySetCounts() public {
        box.set(3);
        box.set(3);
        box.set(0);
        assertEq(box.get(), 0);
        assertEq(box.updateCount(), 3);
        box.set(type(uint256).max);
        assertEq(box.get(), type(uint256).max);
        assertEq(box.updateCount(), 4);
    }

    function testHiddenOwnerIsDeployer() public {
        vm.prank(alice);
        StorageBox other = new StorageBox(1000);
        assertEq(other.owner(), alice);
        assertEq(other.get(), 1000);

        // The test contract deployed `box`, not `other`.
        vm.expectRevert(abi.encodeWithSelector(StorageBox.NotOwner.selector, address(this)));
        other.set(1);

        vm.prank(alice);
        other.set(2);
        assertEq(other.get(), 2);
        assertEq(other.updateCount(), 1);
    }

    function testHiddenZeroInitialValue() public {
        StorageBox zero = new StorageBox(0);
        assertEq(zero.get(), 0);
        assertEq(zero.updateCount(), 0);
    }
}
