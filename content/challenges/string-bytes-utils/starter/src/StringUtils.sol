// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract StringUtils {
    error LengthOutOfRange(uint256 length, uint256 min, uint256 max);

    function byteLength(string calldata s) external pure returns (uint256) {
        // TODO: length of s in bytes
        return 0;
    }

    function equal(string calldata a, string calldata b) external pure returns (bool) {
        // TODO: same length and same keccak256 hash
        return false;
    }

    function bytesEqual(bytes calldata a, bytes calldata b) external pure returns (bool) {
        // TODO: same length and same keccak256 hash
        return false;
    }

    function concat(string calldata a, string calldata b) external pure returns (string memory) {
        // TODO: a followed by b
        return "";
    }

    function concatBytes(bytes calldata a, bytes calldata b) external pure returns (bytes memory) {
        // TODO: a followed by b
        return "";
    }

    function startsWith(string calldata s, string calldata prefix) external pure returns (bool) {
        // TODO: true when s begins with prefix
        return false;
    }

    function isLengthBetween(string calldata s, uint256 min, uint256 max) external pure returns (bool) {
        // TODO: inclusive range check that never reverts
        return false;
    }

    function validateLength(string calldata s, uint256 min, uint256 max) external pure returns (uint256) {
        // TODO: return the length or revert with LengthOutOfRange(length, min, max)
        return 0;
    }
}
