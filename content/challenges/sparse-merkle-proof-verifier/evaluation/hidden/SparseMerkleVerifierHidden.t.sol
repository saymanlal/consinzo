// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SparseMerkleVerifier.sol";

/// Independent sparse Merkle tree model used to build roots and compressed proofs.
abstract contract SmtModel is Test {
    struct Builder {
        uint256[] paths;
        bytes32[] nodes;
        bool[] used;
        uint256 count;
        bytes32 zero;
        uint256 bitmask;
        bytes32[] siblings;
        uint256 siblingCount;
    }

    function _leaf(bytes32 key, bytes32 value) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(bytes1(0x00), key, value));
    }

    function _node(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(bytes1(0x01), left, right));
    }

    /// Root of the tree holding (keys[i] -> values[i]) and the proof for `target`,
    /// which may or may not be one of the keys.
    function _prove(bytes32[] memory keys, bytes32[] memory values, bytes32 target)
        internal
        pure
        returns (bytes32 root, uint256 bitmask, bytes32[] memory siblings)
    {
        Builder memory b;
        b.count = keys.length;
        b.paths = new uint256[](b.count);
        b.nodes = new bytes32[](b.count);
        b.used = new bool[](b.count);
        b.siblings = new bytes32[](256);
        for (uint256 i = 0; i < b.count; i++) {
            b.paths[i] = uint256(keys[i]);
            b.nodes[i] = _leaf(keys[i], values[i]);
        }

        uint256 targetPath = uint256(target);
        for (uint256 h = 0; h < 256; h++) {
            _collectSibling(b, targetPath ^ 1, h);
            _mergeLevel(b);
            targetPath >>= 1;
        }

        root = b.count == 0 ? b.zero : b.nodes[0];
        bitmask = b.bitmask;
        siblings = new bytes32[](b.siblingCount);
        for (uint256 i = 0; i < b.siblingCount; i++) siblings[i] = b.siblings[i];
    }

    function _collectSibling(Builder memory b, uint256 siblingPath, uint256 h) private pure {
        for (uint256 i = 0; i < b.count; i++) {
            if (b.paths[i] == siblingPath) {
                b.bitmask |= uint256(1) << h;
                b.siblings[b.siblingCount++] = b.nodes[i];
                return;
            }
        }
    }

    function _mergeLevel(Builder memory b) private pure {
        uint256 merged = 0;
        for (uint256 i = 0; i < b.count; i++) b.used[i] = false;
        for (uint256 i = 0; i < b.count; i++) {
            if (b.used[i]) continue;
            uint256 path = b.paths[i];
            bytes32 other = b.zero;
            for (uint256 j = i + 1; j < b.count; j++) {
                if (!b.used[j] && b.paths[j] == (path ^ 1)) {
                    b.used[j] = true;
                    other = b.nodes[j];
                    break;
                }
            }
            bytes32 parent = path & 1 == 0 ? _node(b.nodes[i], other) : _node(other, b.nodes[i]);
            b.paths[merged] = path >> 1;
            b.nodes[merged] = parent;
            merged++;
        }
        b.count = merged;
        b.zero = _node(b.zero, b.zero);
    }

    function _keys(uint256 a, uint256 b_, uint256 c, uint256 d) internal pure returns (bytes32[] memory keys) {
        keys = new bytes32[](4);
        keys[0] = bytes32(a);
        keys[1] = bytes32(b_);
        keys[2] = bytes32(c);
        keys[3] = bytes32(d);
    }

    function _values(uint256 n) internal pure returns (bytes32[] memory values) {
        values = new bytes32[](n);
        for (uint256 i = 0; i < n; i++) values[i] = keccak256(abi.encodePacked("value", i));
    }
}

contract SparseMerkleVerifierHiddenTest is SmtModel {
    SparseMerkleVerifier public verifier;

    function setUp() public {
        verifier = new SparseMerkleVerifier();
    }

    function _drop(bytes32[] memory a) internal pure returns (bytes32[] memory out) {
        out = new bytes32[](a.length - 1);
        for (uint256 i = 0; i < out.length; i++) out[i] = a[i];
    }

    function _push(bytes32[] memory a, bytes32 x) internal pure returns (bytes32[] memory out) {
        out = new bytes32[](a.length + 1);
        for (uint256 i = 0; i < a.length; i++) out[i] = a[i];
        out[a.length] = x;
    }

    function testHiddenDefaultHashes() public {
        bytes32 d = bytes32(0);
        for (uint256 h = 0; h < 256; h++) d = _node(d, d);
        assertEq(verifier.defaultHash(256), d);
        assertEq(verifier.emptyRoot(), d);
        bytes32 d100 = bytes32(0);
        for (uint256 h = 0; h < 100; h++) d100 = _node(d100, d100);
        assertEq(verifier.defaultHash(100), d100);

        vm.expectRevert(SparseMerkleVerifier.InvalidHeight.selector);
        verifier.defaultHash(257);
    }

    function testHiddenDomainSeparation() public view {
        bytes32 a = keccak256("a");
        bytes32 b = keccak256("b");
        // Leaf and node hashes of the same inputs differ, and neither is the plain pair hash.
        assertTrue(verifier.leafHash(a, b) != verifier.nodeHash(a, b));
        assertTrue(verifier.nodeHash(a, b) != keccak256(abi.encodePacked(a, b)));
        assertTrue(verifier.nodeHash(a, b) != verifier.nodeHash(b, a));
        assertEq(verifier.leafHash(bytes32(0), bytes32(0)), keccak256(new bytes(65)));
    }

    function testHiddenSingleKeyTreeHasEmptyProof() public view {
        bytes32[] memory keys = new bytes32[](1);
        bytes32[] memory values = new bytes32[](1);
        keys[0] = keccak256("only key");
        values[0] = keccak256("only value");
        (bytes32 root, uint256 bitmask, bytes32[] memory siblings) = _prove(keys, values, keys[0]);
        assertEq(bitmask, 0);
        assertEq(siblings.length, 0);
        assertTrue(verifier.verifyInclusion(root, keys[0], values[0], 0, siblings));
        assertFalse(verifier.verifyInclusion(verifier.emptyRoot(), keys[0], values[0], 0, siblings));
        assertFalse(verifier.verifyNonInclusion(root, keys[0], 0, siblings));
        // In the empty tree the same key is absent.
        assertTrue(verifier.verifyNonInclusion(verifier.emptyRoot(), keys[0], 0, siblings));
    }

    function testHiddenAdjacentKeys() public view {
        // Keys 0 and 1 are siblings at height 0.
        bytes32[] memory keys = new bytes32[](1);
        bytes32[] memory values = new bytes32[](1);
        keys[0] = bytes32(0);
        values[0] = keccak256("zero");
        bytes32 one = bytes32(uint256(1));

        (bytes32 root, uint256 bitmask, bytes32[] memory siblings) = _prove(keys, values, one);
        assertEq(bitmask, 1);
        assertEq(siblings.length, 1);
        assertEq(siblings[0], _leaf(keys[0], values[0]));
        assertTrue(verifier.verifyNonInclusion(root, one, bitmask, siblings));
        // The proof for key 1 says nothing about key 3.
        assertFalse(verifier.verifyNonInclusion(root, bytes32(uint256(3)), bitmask, siblings));
        // Using the wrong side order must fail: same proof for key 0 itself.
        assertFalse(verifier.verifyNonInclusion(root, bytes32(0), bitmask, siblings));
    }

    function testHiddenKeysDifferingOnlyInTopBit() public view {
        bytes32[] memory keys = new bytes32[](2);
        bytes32[] memory values = _values(2);
        keys[0] = bytes32(uint256(9));
        keys[1] = bytes32(uint256(9) | (uint256(1) << 255));

        (bytes32 root, uint256 bitmask, bytes32[] memory siblings) = _prove(keys, values, keys[1]);
        assertEq(bitmask, uint256(1) << 255);
        assertTrue(verifier.verifyInclusion(root, keys[1], values[1], bitmask, siblings));
        assertFalse(verifier.verifyInclusion(root, keys[0], values[1], bitmask, siblings));

        (root, bitmask, siblings) = _prove(keys, values, keys[0]);
        assertTrue(verifier.verifyInclusion(root, keys[0], values[0], bitmask, siblings));
    }

    function testHiddenHashedKeys() public view {
        bytes32[] memory keys = new bytes32[](3);
        bytes32[] memory values = _values(3);
        for (uint256 i = 0; i < 3; i++) keys[i] = keccak256(abi.encodePacked("account", i));

        (bytes32 root, uint256 bitmask, bytes32[] memory siblings) = _prove(keys, values, keys[1]);
        assertTrue(verifier.verifyInclusion(root, keys[1], values[1], bitmask, siblings));
        assertFalse(verifier.verifyInclusion(root, keys[1], values[2], bitmask, siblings));

        bytes32 absent = keccak256("no such account");
        (root, bitmask, siblings) = _prove(keys, values, absent);
        assertTrue(verifier.verifyNonInclusion(root, absent, bitmask, siblings));
        assertFalse(verifier.verifyNonInclusion(root, keys[0], bitmask, siblings));
    }

    function testHiddenZeroValueIsPresentNotAbsent() public view {
        bytes32[] memory keys = _keys(4, 5, 6, 1000);
        bytes32[] memory values = _values(4);
        values[1] = bytes32(0);
        (bytes32 root, uint256 bitmask, bytes32[] memory siblings) = _prove(keys, values, keys[1]);
        assertTrue(verifier.verifyInclusion(root, keys[1], bytes32(0), bitmask, siblings));
        assertFalse(verifier.verifyNonInclusion(root, keys[1], bitmask, siblings));
    }

    function testHiddenTamperedProofsAreRejected() public view {
        bytes32[] memory keys = _keys(8, 9, 10, 300);
        bytes32[] memory values = _values(4);
        (bytes32 root, uint256 bitmask, bytes32[] memory siblings) = _prove(keys, values, keys[0]);
        assertGt(siblings.length, 1);
        assertTrue(verifier.verifyInclusion(root, keys[0], values[0], bitmask, siblings));

        // Flip one sibling.
        bytes32 saved = siblings[1];
        siblings[1] = bytes32(uint256(saved) ^ 1);
        assertFalse(verifier.verifyInclusion(root, keys[0], values[0], bitmask, siblings));
        siblings[1] = saved;

        // Swap two siblings.
        (siblings[0], siblings[1]) = (siblings[1], siblings[0]);
        assertFalse(verifier.verifyInclusion(root, keys[0], values[0], bitmask, siblings));
        (siblings[0], siblings[1]) = (siblings[1], siblings[0]);

        // Move a sibling to a different height: same count, different bitmask.
        uint256 lowest = bitmask & (~bitmask + 1);
        uint256 moved = (bitmask ^ lowest) | (uint256(1) << 77);
        assertFalse(verifier.verifyInclusion(root, keys[0], values[0], moved, siblings));

        // Wrong root.
        assertFalse(verifier.verifyInclusion(bytes32(uint256(root) ^ 1), keys[0], values[0], bitmask, siblings));
    }

    function testHiddenMalformedLengthsRevert() public {
        bytes32[] memory keys = _keys(8, 9, 10, 300);
        bytes32[] memory values = _values(4);
        (bytes32 root, uint256 bitmask, bytes32[] memory siblings) = _prove(keys, values, keys[0]);

        bytes32[] memory shorter = _drop(siblings);
        bytes32[] memory longer = _push(siblings, bytes32(0));

        vm.expectRevert(SparseMerkleVerifier.InvalidProofLength.selector);
        verifier.verifyInclusion(root, keys[0], values[0], bitmask, shorter);
        vm.expectRevert(SparseMerkleVerifier.InvalidProofLength.selector);
        verifier.verifyNonInclusion(root, keys[0], bitmask, longer);
        vm.expectRevert(SparseMerkleVerifier.InvalidProofLength.selector);
        verifier.computeRoot(keys[0], bytes32(0), bitmask, longer);

        // Extra sibling with an empty bitmask.
        bytes32 empty = verifier.emptyRoot();
        bytes32[] memory one = new bytes32[](1);
        vm.expectRevert(SparseMerkleVerifier.InvalidProofLength.selector);
        verifier.verifyNonInclusion(empty, keys[0], 0, one);
        // Bit set at the very top with no sibling supplied.
        bytes32[] memory none = new bytes32[](0);
        vm.expectRevert(SparseMerkleVerifier.InvalidProofLength.selector);
        verifier.verifyNonInclusion(empty, keys[0], uint256(1) << 255, none);
    }

    function testHiddenProofForOneKeyDoesNotProveAnother() public view {
        bytes32[] memory keys = _keys(16, 17, 18, 19);
        bytes32[] memory values = _values(4);
        (bytes32 root, uint256 bitmask, bytes32[] memory siblings) = _prove(keys, values, keys[2]);
        assertTrue(verifier.verifyInclusion(root, keys[2], values[2], bitmask, siblings));
        assertFalse(verifier.verifyInclusion(root, keys[3], values[2], bitmask, siblings));
        assertFalse(verifier.verifyInclusion(root, keys[3], values[3], bitmask, siblings));
        // computeRoot takes the leaf as given: an inner-looking leaf yields a different root.
        assertTrue(verifier.computeRoot(keys[2], values[2], bitmask, siblings) != root);
    }
}
