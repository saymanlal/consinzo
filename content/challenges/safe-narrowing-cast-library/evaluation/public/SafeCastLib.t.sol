// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SafeCastLib.sol";

/// Exposes the internal library functions so that reverts can be observed from outside.
contract CastHarness {
    using SafeCastLib for uint256;

    function toUint128(uint256 value) external pure returns (uint128) {
        return value.toUint128();
    }

    function toUint64(uint256 value) external pure returns (uint64) {
        return value.toUint64();
    }

    function toUint32(uint256 value) external pure returns (uint32) {
        return value.toUint32();
    }

    function fits(uint256 value, uint8 bits) external pure returns (bool) {
        return SafeCastLib.fits(value, bits);
    }
}

contract SafeCastLibTest is Test {
    CastHarness public harness;

    function setUp() public {
        harness = new CastHarness();
    }

    function testSmallValuesPassThrough() public {
        assertEq(uint256(harness.toUint128(42)), 42);
        assertEq(uint256(harness.toUint64(42)), 42);
        assertEq(uint256(harness.toUint32(42)), 42);
        assertEq(uint256(harness.toUint32(0)), 0);
    }

    function testMaximumValuesFit() public {
        assertEq(uint256(harness.toUint128(type(uint128).max)), type(uint128).max);
        assertEq(uint256(harness.toUint64(type(uint64).max)), type(uint64).max);
        assertEq(uint256(harness.toUint32(type(uint32).max)), type(uint32).max);
    }

    function testUint64OverflowReverts() public {
        uint256 tooBig = uint256(type(uint64).max) + 1;
        vm.expectRevert(abi.encodeWithSelector(SafeCastLib.CastOverflow.selector, uint8(64), tooBig));
        harness.toUint64(tooBig);
    }

    function testUint32AndUint128OverflowRevert() public {
        vm.expectRevert(SafeCastLib.CastOverflow.selector);
        harness.toUint32(uint256(type(uint32).max) + 1);

        vm.expectRevert(SafeCastLib.CastOverflow.selector);
        harness.toUint128(uint256(type(uint128).max) + 1);
    }

    function testFits() public {
        assertTrue(harness.fits(255, 8));
        assertFalse(harness.fits(256, 8));
        assertTrue(harness.fits(type(uint64).max, 64));
        assertFalse(harness.fits(uint256(type(uint64).max) + 1, 64));
    }
}
