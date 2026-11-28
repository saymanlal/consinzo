// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

library AsmBytes {
    error OutOfBounds();

    /// @notice Returns a new array with the same contents as `src`.
    function copy(bytes memory src) internal pure returns (bytes memory dst) {
        assembly {
            let len := mload(src)
            dst := mload(0x40)
            mstore(dst, len)

            let from := add(src, 0x20)
            let to := add(dst, 0x20)
            // Whole words. The last iteration may copy bytes that lie behind the end of
            // `src`; they land in memory we own and are cleared right below.
            for { let end := add(from, len) } lt(from, end) {
                from := add(from, 0x20)
                to := add(to, 0x20)
            } { mstore(to, mload(from)) }

            // Zero the word that starts at the logical end. This clears the padding of a
            // partially used last word (and harmlessly zeroes free memory behind it).
            let tail := add(add(dst, 0x20), len)
            mstore(tail, 0)
            // Advance the free memory pointer to the next 32-byte boundary.
            mstore(0x40, and(add(tail, 0x1f), not(0x1f)))
        }
    }

    /// @notice Returns data[start .. start + length) as a new array.
    function slice(bytes memory data, uint256 start, uint256 length) internal pure returns (bytes memory result) {
        // Written as two comparisons so that start + length cannot overflow.
        uint256 total = data.length;
        if (start > total || length > total - start) revert OutOfBounds();

        assembly {
            result := mload(0x40)
            mstore(result, length)

            let from := add(add(data, 0x20), start)
            let to := add(result, 0x20)
            for { let end := add(from, length) } lt(from, end) {
                from := add(from, 0x20)
                to := add(to, 0x20)
            } { mstore(to, mload(from)) }

            let tail := add(add(result, 0x20), length)
            mstore(tail, 0)
            mstore(0x40, and(add(tail, 0x1f), not(0x1f)))
        }
    }

    /// @notice Equivalent to abi.encodePacked(a, b).
    function concat(bytes memory a, bytes memory b) internal pure returns (bytes memory result) {
        assembly {
            let lenA := mload(a)
            let lenB := mload(b)
            result := mload(0x40)
            mstore(result, add(lenA, lenB))

            let to := add(result, 0x20)
            let from := add(a, 0x20)
            for { let end := add(from, lenA) } lt(from, end) {
                from := add(from, 0x20)
                to := add(to, 0x20)
            } { mstore(to, mload(from)) }

            // `to` overshot if lenA is not a multiple of 32; restart exactly behind `a`.
            // Copying `b` afterwards overwrites the overshoot of the first loop.
            to := add(add(result, 0x20), lenA)
            from := add(b, 0x20)
            for { let end := add(from, lenB) } lt(from, end) {
                from := add(from, 0x20)
                to := add(to, 0x20)
            } { mstore(to, mload(from)) }

            let tail := add(add(add(result, 0x20), lenA), lenB)
            mstore(tail, 0)
            mstore(0x40, and(add(tail, 0x1f), not(0x1f)))
        }
    }

    /// @notice Equivalent to keccak256(abi.encodePacked(a, b)). Must not allocate.
    function hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32 digest) {
        assembly {
            // Exactly the 64 bytes of scratch space.
            mstore(0x00, a)
            mstore(0x20, b)
            digest := keccak256(0x00, 0x40)
        }
    }

    /// @notice Equivalent to keccak256(abi.encodePacked(a, b, c)). Must not allocate.
    function hashTriple(bytes32 a, bytes32 b, bytes32 c) internal pure returns (bytes32 digest) {
        assembly {
            // A third word at 0x40 would overwrite the free memory pointer. Use the
            // unallocated region behind the pointer instead and leave the pointer alone.
            let ptr := mload(0x40)
            mstore(ptr, a)
            mstore(add(ptr, 0x20), b)
            mstore(add(ptr, 0x40), c)
            digest := keccak256(ptr, 0x60)
        }
    }

    /// @notice Equivalent to keccak256(abi.encodePacked(account, amount, salt)). Must not allocate.
    function hashPacked(address account, uint96 amount, bytes32 salt) internal pure returns (bytes32 digest) {
        assembly {
            // First word: 20 address bytes followed by 12 amount bytes. The shift drops any
            // dirty upper bits of `account`; the mask does the same for `amount`.
            mstore(0x00, or(shl(96, account), and(amount, 0xffffffffffffffffffffffff)))
            mstore(0x20, salt)
            digest := keccak256(0x00, 0x40)
        }
    }

    /// @notice Equivalent to keccak256(abi.encodePacked(a, b)). Must not allocate.
    function hashConcat(bytes memory a, bytes memory b) internal pure returns (bytes32 digest) {
        assembly {
            let lenA := mload(a)
            let lenB := mload(b)
            // Build the concatenation in free memory and never claim it.
            let ptr := mload(0x40)

            let to := ptr
            let from := add(a, 0x20)
            for { let end := add(from, lenA) } lt(from, end) {
                from := add(from, 0x20)
                to := add(to, 0x20)
            } { mstore(to, mload(from)) }

            to := add(ptr, lenA)
            from := add(b, 0x20)
            for { let end := add(from, lenB) } lt(from, end) {
                from := add(from, 0x20)
                to := add(to, 0x20)
            } { mstore(to, mload(from)) }

            digest := keccak256(ptr, add(lenA, lenB))
        }
    }
}
