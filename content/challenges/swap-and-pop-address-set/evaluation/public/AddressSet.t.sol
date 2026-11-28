// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AddressSet.sol";

contract AddressSetTest is Test {
    AddressSet public set;
    address public a = address(0xA);
    address public b = address(0xB);
    address public c = address(0xC);
    address public d = address(0xD);

    function setUp() public {
        set = new AddressSet();
    }

    function testAddAndContains() public {
        assertTrue(set.add(a));
        assertTrue(set.add(b));
        assertTrue(set.contains(a));
        assertTrue(set.contains(b));
        assertFalse(set.contains(c));
        assertEq(set.length(), 2);
        assertEq(set.at(0), a);
        assertEq(set.at(1), b);
    }

    function testAddDuplicateReturnsFalse() public {
        assertTrue(set.add(a));
        assertFalse(set.add(a));
        assertEq(set.length(), 1);
    }

    function testRemoveSwapsLastIntoHole() public {
        set.add(a);
        set.add(b);
        set.add(c);
        set.add(d);

        assertTrue(set.remove(a));
        assertFalse(set.contains(a));
        assertEq(set.length(), 3);
        assertEq(set.at(0), d);
        assertEq(set.at(1), b);
        assertEq(set.at(2), c);
    }

    function testRemoveMissingReturnsFalse() public {
        set.add(a);
        assertFalse(set.remove(b));
        assertEq(set.length(), 1);
    }

    function testAtOutOfBoundsReverts() public {
        set.add(a);
        vm.expectRevert(abi.encodeWithSelector(AddressSet.IndexOutOfBounds.selector, uint256(1), uint256(1)));
        set.at(1);
    }
}
