// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

library SafeCastLib {
    /// @param bits  width of the type the value was being narrowed to
    /// @param value the value that did not fit
    error CastOverflow(uint8 bits, uint256 value);

    function toUint128(uint256 value) internal pure returns (uint128) {
        if (value > type(uint128).max) revert CastOverflow(128, value);
        // Safe: the check above guarantees no high bits are discarded.
        return uint128(value);
    }

    function toUint64(uint256 value) internal pure returns (uint64) {
        if (value > type(uint64).max) revert CastOverflow(64, value);
        return uint64(value);
    }

    function toUint32(uint256 value) internal pure returns (uint32) {
        if (value > type(uint32).max) revert CastOverflow(32, value);
        return uint32(value);
    }

    function fits(uint256 value, uint8 bits) internal pure returns (bool) {
        // Shifting right by `bits` leaves exactly the bits that would be lost.
        // A shift never reverts, unlike `2 ** bits`, and `bits` is at most 255.
        return value >> bits == 0;
    }
}
