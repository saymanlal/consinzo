// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AddressSet.sol";

contract AddressSetHiddenTest is Test {
    AddressSet public set;
    address public a = address(0xA);
    address public b = address(0xB);
    address public c = address(0xC);
    address public d = address(0xD);

    function setUp() public {
        set = new AddressSet();
    }

    function _fill() internal {
        set.add(a);
        set.add(b);
        set.add(c);
        set.add(d);
    }

    function _assertValues(address[] memory expected) internal view {
        address[] memory actual = set.values();
        assertEq(actual.length, expected.length);
        assertEq(set.length(), expected.length);
        for (uint256 i = 0; i < expected.length; i++) {
            assertEq(actual[i], expected[i]);
            assertEq(set.at(i), expected[i]);
            assertTrue(set.contains(expected[i]));
        }
    }

    function _list(address x, address y) internal pure returns (address[] memory r) {
        r = new address[](2);
        r[0] = x;
        r[1] = y;
    }

    function _list(address x, address y, address z) internal pure returns (address[] memory r) {
        r = new address[](3);
        r[0] = x;
        r[1] = y;
        r[2] = z;
    }

    function testHiddenRemoveMovedElement() public {
        _fill();
        set.remove(a); // [d, b, c]
        _assertValues(_list(d, b, c));

        // d was moved by the previous removal; its index must have been updated.
        assertTrue(set.remove(d)); // [c, b]
        _assertValues(_list(c, b));
        assertFalse(set.contains(d));
        assertFalse(set.contains(a));

        assertTrue(set.add(a)); // [c, b, a]
        _assertValues(_list(c, b, a));
    }

    function testHiddenRemoveLastElement() public {
        _fill();
        assertTrue(set.remove(d)); // [a, b, c]
        _assertValues(_list(a, b, c));
        assertFalse(set.contains(d));

        // A stale index for d would make this second removal corrupt the set.
        assertFalse(set.remove(d));
        _assertValues(_list(a, b, c));

        assertTrue(set.add(d));
        assertEq(set.at(3), d);
        assertEq(set.length(), 4);
    }

    function testHiddenRemoveMiddleElement() public {
        _fill();
        assertTrue(set.remove(b)); // [a, d, c]
        _assertValues(_list(a, d, c));
        assertTrue(set.remove(c)); // [a, d]
        _assertValues(_list(a, d));
    }

    function testHiddenRemoveOnlyElement() public {
        set.add(a);
        assertTrue(set.remove(a));
        assertEq(set.length(), 0);
        assertEq(set.values().length, 0);
        assertFalse(set.contains(a));

        vm.expectRevert(abi.encodeWithSelector(AddressSet.IndexOutOfBounds.selector, uint256(0), uint256(0)));
        set.at(0);

        assertTrue(set.add(a));
        assertEq(set.at(0), a);
    }

    function testHiddenZeroAddressIsAValidMember() public {
        assertFalse(set.contains(address(0)));
        assertTrue(set.add(address(0)));
        assertTrue(set.contains(address(0)));
        assertFalse(set.add(address(0)));
        assertEq(set.length(), 1);
        assertEq(set.at(0), address(0));

        set.add(a);
        assertTrue(set.remove(address(0))); // [a]
        assertFalse(set.contains(address(0)));
        assertEq(set.at(0), a);
        assertEq(set.length(), 1);
        assertFalse(set.remove(address(0)));
    }

    function testHiddenFirstElementIsNotMistakenForMissing() public {
        // The element at position 0 must be found by contains and remove.
        set.add(a);
        set.add(b);
        assertTrue(set.contains(a));
        assertFalse(set.add(a));
        assertTrue(set.remove(a)); // [b]
        assertEq(set.at(0), b);
        assertTrue(set.remove(b));
        assertEq(set.length(), 0);
    }

    function testHiddenRemoveFromEmptySet() public {
        assertFalse(set.remove(a));
        assertEq(set.length(), 0);
    }

    function testHiddenDrainAndRefill() public {
        _fill();
        assertTrue(set.remove(b)); // [a, d, c]
        assertTrue(set.remove(a)); // [c, d]
        assertTrue(set.remove(c)); // [d]
        assertTrue(set.remove(d)); // []
        assertEq(set.length(), 0);
        assertFalse(set.contains(a));
        assertFalse(set.contains(b));
        assertFalse(set.contains(c));
        assertFalse(set.contains(d));

        set.add(c);
        set.add(a);
        _assertValues(_list(c, a));
    }

    function testHiddenManyElements() public {
        for (uint160 i = 1; i <= 20; i++) {
            assertTrue(set.add(address(i)));
        }
        // Remove every even address.
        for (uint160 i = 2; i <= 20; i += 2) {
            assertTrue(set.remove(address(i)));
        }
        assertEq(set.length(), 10);
        address[] memory members = set.values();
        for (uint256 i = 0; i < members.length; i++) {
            assertEq(uint256(uint160(members[i])) % 2, 1);
            assertEq(set.at(i), members[i]);
        }
        for (uint160 i = 1; i <= 20; i++) {
            assertEq(set.contains(address(i)), i % 2 == 1);
        }
    }
}
