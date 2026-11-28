// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract StringUtils {
    error LengthOutOfRange(uint256 length, uint256 min, uint256 max);

    function byteLength(string calldata s) external pure returns (uint256) {
        // A string has no length member; its bytes view does.
        return bytes(s).length;
    }

    function equal(string calldata a, string calldata b) external pure returns (bool) {
        return _bytesEqual(bytes(a), bytes(b));
    }

    function bytesEqual(bytes calldata a, bytes calldata b) external pure returns (bool) {
        return _bytesEqual(a, b);
    }

    function concat(string calldata a, string calldata b) external pure returns (string memory) {
        return string.concat(a, b);
    }

    function concatBytes(bytes calldata a, bytes calldata b) external pure returns (bytes memory) {
        return bytes.concat(a, b);
    }

    function startsWith(string calldata s, string calldata prefix) external pure returns (bool) {
        bytes calldata sBytes = bytes(s);
        bytes calldata prefixBytes = bytes(prefix);

        uint256 prefixLength = prefixBytes.length;
        if (prefixLength > sBytes.length) return false;

        // Compare the leading slice of s with the prefix. Slicing calldata is free of copies.
        return keccak256(sBytes[:prefixLength]) == keccak256(prefixBytes);
    }

    function isLengthBetween(string calldata s, uint256 min, uint256 max) external pure returns (bool) {
        uint256 len = bytes(s).length;
        return len >= min && len <= max;
    }

    function validateLength(string calldata s, uint256 min, uint256 max) external pure returns (uint256) {
        uint256 len = bytes(s).length;
        if (len < min || len > max) revert LengthOutOfRange(len, min, max);
        return len;
    }

    function _bytesEqual(bytes calldata a, bytes calldata b) internal pure returns (bool) {
        // The length check is a cheap early exit; the hash comparison decides the rest.
        if (a.length != b.length) return false;
        return keccak256(a) == keccak256(b);
    }
}
