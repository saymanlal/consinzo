// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

library SafeCastLib {
    /// @param bits  width of the type the value was being narrowed to
    /// @param value the value that did not fit
    error CastOverflow(uint8 bits, uint256 value);

    function toUint128(uint256 value) internal pure returns (uint128) {
        // TODO: revert with CastOverflow(128, value) when value does not fit, otherwise cast
        revert("NOT_IMPLEMENTED");
    }

    function toUint64(uint256 value) internal pure returns (uint64) {
        // TODO: revert with CastOverflow(64, value) when value does not fit, otherwise cast
        revert("NOT_IMPLEMENTED");
    }

    function toUint32(uint256 value) internal pure returns (uint32) {
        // TODO: revert with CastOverflow(32, value) when value does not fit, otherwise cast
        revert("NOT_IMPLEMENTED");
    }

    function fits(uint256 value, uint8 bits) internal pure returns (bool) {
        // TODO: true when value < 2 ** bits; must not revert for any input
        revert("NOT_IMPLEMENTED");
    }
}
