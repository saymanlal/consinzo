// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract SparseMerkleVerifier {
    error InvalidProofLength();
    error InvalidHeight();

    uint256 public constant DEPTH = 256;

    function leafHash(bytes32 key, bytes32 value) public pure returns (bytes32) {
        // TODO: keccak256(abi.encodePacked(bytes1(0x00), key, value))
        revert("NOT_IMPLEMENTED");
    }

    function nodeHash(bytes32 left, bytes32 right) public pure returns (bytes32) {
        // TODO: keccak256(abi.encodePacked(bytes1(0x01), left, right))
        revert("NOT_IMPLEMENTED");
    }

    function defaultHash(uint256 height) public pure returns (bytes32) {
        // TODO: root of an empty subtree of the given height; InvalidHeight above 256.
        revert("NOT_IMPLEMENTED");
    }

    function emptyRoot() external pure returns (bytes32) {
        // TODO
        revert("NOT_IMPLEMENTED");
    }

    function computeRoot(bytes32 key, bytes32 leaf, uint256 bitmask, bytes32[] calldata siblings)
        public
        pure
        returns (bytes32)
    {
        // TODO: fold the leaf with 256 siblings, taking each one from `siblings` when the
        //       bitmask bit is set and from the default hashes otherwise.
        // TODO: revert with InvalidProofLength when the sibling count does not match.
        revert("NOT_IMPLEMENTED");
    }

    function verifyInclusion(bytes32 root, bytes32 key, bytes32 value, uint256 bitmask, bytes32[] calldata siblings)
        external
        pure
        returns (bool)
    {
        // TODO
        revert("NOT_IMPLEMENTED");
    }

    function verifyNonInclusion(bytes32 root, bytes32 key, uint256 bitmask, bytes32[] calldata siblings)
        external
        pure
        returns (bool)
    {
        // TODO
        revert("NOT_IMPLEMENTED");
    }
}
