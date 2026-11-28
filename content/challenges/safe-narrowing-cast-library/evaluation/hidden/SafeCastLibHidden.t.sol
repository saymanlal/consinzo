// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SafeCastLib.sol";

contract HiddenCastHarness {
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

    /// Typical use: narrowing three fields before packing them into one word.
    function pack(uint256 amount, uint256 timestamp, uint256 id) external pure returns (uint256) {
        return (uint256(amount.toUint128()) << 96) | (uint256(timestamp.toUint64()) << 32) | id.toUint32();
    }
}

contract SafeCastLibHiddenTest is Test {
    HiddenCastHarness public harness;

    function setUp() public {
        harness = new HiddenCastHarness();
    }

    function testHiddenExactErrorArgumentsFor128() public {
        uint256 tooBig = uint256(type(uint128).max) + 1;
        vm.expectRevert(abi.encodeWithSelector(SafeCastLib.CastOverflow.selector, uint8(128), tooBig));
        harness.toUint128(tooBig);

        vm.expectRevert(
            abi.encodeWithSelector(SafeCastLib.CastOverflow.selector, uint8(128), type(uint256).max)
        );
        harness.toUint128(type(uint256).max);
    }

    function testHiddenExactErrorArgumentsFor32() public {
        vm.expectRevert(abi.encodeWithSelector(SafeCastLib.CastOverflow.selector, uint8(32), uint256(1) << 32));
        harness.toUint32(uint256(1) << 32);

        // Fits in 64 bits but not in 32.
        vm.expectRevert(
            abi.encodeWithSelector(SafeCastLib.CastOverflow.selector, uint8(32), uint256(type(uint64).max))
        );
        harness.toUint32(type(uint64).max);
    }

    function testHiddenLowBitsZeroStillOverflows() public {
        // A truncating cast would return 0 for each of these.
        vm.expectRevert(abi.encodeWithSelector(SafeCastLib.CastOverflow.selector, uint8(64), uint256(1) << 64));
        harness.toUint64(uint256(1) << 64);

        vm.expectRevert(abi.encodeWithSelector(SafeCastLib.CastOverflow.selector, uint8(64), uint256(1) << 255));
        harness.toUint64(uint256(1) << 255);

        vm.expectRevert(abi.encodeWithSelector(SafeCastLib.CastOverflow.selector, uint8(128), uint256(7) << 128));
        harness.toUint128(uint256(7) << 128);
    }

    function testHiddenValuesBetweenWidths() public {
        uint256 v = uint256(type(uint32).max) + 1;
        assertEq(uint256(harness.toUint64(v)), v);
        assertEq(uint256(harness.toUint128(v)), v);

        uint256 w = uint256(type(uint64).max) + 1;
        assertEq(uint256(harness.toUint128(w)), w);

        assertEq(uint256(harness.toUint32(0xDEADBEEF)), 0xDEADBEEF);
        assertEq(uint256(harness.toUint64(0x0123456789ABCDEF)), 0x0123456789ABCDEF);
    }

    function testHiddenFitsBoundaries() public {
        assertTrue(harness.fits(0, 0));
        assertFalse(harness.fits(1, 0));
        assertTrue(harness.fits(1, 1));
        assertFalse(harness.fits(2, 1));
        assertTrue(harness.fits(type(uint32).max, 32));
        assertFalse(harness.fits(uint256(1) << 32, 32));
        assertTrue(harness.fits(type(uint128).max, 128));
        assertFalse(harness.fits(uint256(1) << 128, 128));
        assertTrue(harness.fits((uint256(1) << 255) - 1, 255));
        assertFalse(harness.fits(uint256(1) << 255, 255));
        assertFalse(harness.fits(type(uint256).max, 255));
        assertTrue(harness.fits(0, 255));
    }

    function testHiddenFitsAgreesWithCasts() public {
        uint256[6] memory samples = [
            uint256(0),
            type(uint32).max,
            uint256(type(uint32).max) + 1,
            type(uint64).max,
            uint256(type(uint64).max) + 1,
            type(uint128).max
        ];
        for (uint256 i = 0; i < samples.length; i++) {
            if (harness.fits(samples[i], 32)) {
                assertEq(uint256(harness.toUint32(samples[i])), samples[i]);
            }
            if (harness.fits(samples[i], 64)) {
                assertEq(uint256(harness.toUint64(samples[i])), samples[i]);
            }
            assertTrue(harness.fits(samples[i], 128));
            assertEq(uint256(harness.toUint128(samples[i])), samples[i]);
        }
        assertFalse(harness.fits(samples[2], 32));
        assertFalse(harness.fits(samples[4], 64));
    }

    function testHiddenPackingRejectsOversizedField() public {
        uint256 packed = harness.pack(5 ether, 1_700_000_000, 77);
        assertEq(packed >> 96, 5 ether);
        assertEq((packed >> 32) & type(uint64).max, 1_700_000_000);
        assertEq(packed & type(uint32).max, 77);

        vm.expectRevert(
            abi.encodeWithSelector(SafeCastLib.CastOverflow.selector, uint8(64), uint256(1) << 70)
        );
        harness.pack(5 ether, uint256(1) << 70, 77);

        vm.expectRevert(
            abi.encodeWithSelector(SafeCastLib.CastOverflow.selector, uint8(32), uint256(1) << 40)
        );
        harness.pack(5 ether, 1_700_000_000, uint256(1) << 40);
    }
}
