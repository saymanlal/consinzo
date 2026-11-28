// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract SparseMerkleVerifier {
    error InvalidProofLength();
    error InvalidHeight();

    uint256 public constant DEPTH = 256;

    /// Leaves and inner nodes use different prefixes so that an inner node can never be
    /// presented as a leaf (or the other way round).
    function leafHash(bytes32 key, bytes32 value) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(bytes1(0x00), key, value));
    }

    function nodeHash(bytes32 left, bytes32 right) public pure returns (bytes32 digest) {
        // Same as keccak256(abi.encodePacked(bytes1(0x01), left, right)), built in free
        // memory without moving the free memory pointer: this runs 512 times per proof.
        assembly {
            let ptr := mload(0x40)
            mstore8(ptr, 0x01)
            mstore(add(ptr, 0x01), left)
            mstore(add(ptr, 0x21), right)
            digest := keccak256(ptr, 0x41)
        }
    }

    function defaultHash(uint256 height) public pure returns (bytes32 digest) {
        if (height > DEPTH) revert InvalidHeight();
        for (uint256 i = 0; i < height; ++i) {
            digest = nodeHash(digest, digest);
        }
    }

    function emptyRoot() external pure returns (bytes32) {
        return defaultHash(DEPTH);
    }

    function computeRoot(bytes32 key, bytes32 leaf, uint256 bitmask, bytes32[] calldata siblings)
        public
        pure
        returns (bytes32 node)
    {
        node = leaf;
        uint256 path = uint256(key);
        uint256 used = 0;
        bytes32 emptySubtree = bytes32(0); // defaultHash(h), advanced once per level

        for (uint256 h = 0; h < DEPTH; ++h) {
            bytes32 sibling;
            if ((bitmask >> h) & 1 == 1) {
                if (used == siblings.length) revert InvalidProofLength();
                sibling = siblings[used++];
            } else {
                sibling = emptySubtree;
            }

            node = (path >> h) & 1 == 1 ? nodeHash(sibling, node) : nodeHash(node, sibling);
            emptySubtree = nodeHash(emptySubtree, emptySubtree);
        }

        // Unused siblings would make proofs malleable.
        if (used != siblings.length) revert InvalidProofLength();
    }

    function verifyInclusion(bytes32 root, bytes32 key, bytes32 value, uint256 bitmask, bytes32[] calldata siblings)
        external
        pure
        returns (bool)
    {
        return computeRoot(key, leafHash(key, value), bitmask, siblings) == root;
    }

    function verifyNonInclusion(bytes32 root, bytes32 key, uint256 bitmask, bytes32[] calldata siblings)
        external
        pure
        returns (bool)
    {
        // An absent key has the empty leaf at its position.
        return computeRoot(key, bytes32(0), bitmask, siblings) == root;
    }
}
