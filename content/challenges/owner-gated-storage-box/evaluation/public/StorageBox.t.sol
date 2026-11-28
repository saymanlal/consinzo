// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StorageBox.sol";

contract StorageBoxTest is Test {
    StorageBox public box;
    address public alice = address(0xA11CE);

    function setUp() public {
        box = new StorageBox(42);
    }

    function testInitialState() public view {
        assertEq(box.get(), 42);
        assertEq(box.owner(), address(this));
        assertEq(box.updateCount(), 0);
    }

    function testOwnerCanSet() public {
        box.set(7);
        assertEq(box.get(), 7);
        assertEq(box.updateCount(), 1);
    }

    function testStrangerCannotSet() public {
        vm.prank(alice);
        vm.expectRevert(StorageBox.NotOwner.selector);
        box.set(99);
        assertEq(box.get(), 42);
    }
}
