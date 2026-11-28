// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

library AsmBytes {
    error OutOfBounds();

    /// @notice Returns a new array with the same contents as `src`.
    function copy(bytes memory src) internal pure returns (bytes memory dst) {
        // TODO: allocate at the free memory pointer, copy word by word, update the pointer.
        revert("NOT_IMPLEMENTED");
    }

    /// @notice Returns data[start .. start + length) as a new array.
    function slice(bytes memory data, uint256 start, uint256 length) internal pure returns (bytes memory result) {
        // TODO: revert with OutOfBounds() when the range does not fit (mind overflow).
        revert("NOT_IMPLEMENTED");
    }

    /// @notice Equivalent to abi.encodePacked(a, b).
    function concat(bytes memory a, bytes memory b) internal pure returns (bytes memory result) {
        // TODO
        revert("NOT_IMPLEMENTED");
    }

    /// @notice Equivalent to keccak256(abi.encodePacked(a, b)). Must not allocate.
    function hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32 digest) {
        // TODO: use the scratch space.
        revert("NOT_IMPLEMENTED");
    }

    /// @notice Equivalent to keccak256(abi.encodePacked(a, b, c)). Must not allocate.
    function hashTriple(bytes32 a, bytes32 b, bytes32 c) internal pure returns (bytes32 digest) {
        // TODO: three words do not fit into the scratch space.
        revert("NOT_IMPLEMENTED");
    }

    /// @notice Equivalent to keccak256(abi.encodePacked(account, amount, salt)). Must not allocate.
    function hashPacked(address account, uint96 amount, bytes32 salt) internal pure returns (bytes32 digest) {
        // TODO: 20 + 12 + 32 bytes.
        revert("NOT_IMPLEMENTED");
    }

    /// @notice Equivalent to keccak256(abi.encodePacked(a, b)). Must not allocate.
    function hashConcat(bytes memory a, bytes memory b) internal pure returns (bytes32 digest) {
        // TODO
        revert("NOT_IMPLEMENTED");
    }
}
