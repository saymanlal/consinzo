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

contract SparseMerkleVerifierTest is SmtModel {
    SparseMerkleVerifier public verifier;

    function setUp() public {
        verifier = new SparseMerkleVerifier();
    }

    function testHashDefinitions() public view {
        bytes32 k = keccak256("k");
        bytes32 v = keccak256("v");
        assertEq(verifier.leafHash(k, v), _leaf(k, v));
        assertEq(verifier.nodeHash(k, v), _node(k, v));
        assertEq(verifier.defaultHash(0), bytes32(0));
        assertEq(verifier.defaultHash(1), _node(bytes32(0), bytes32(0)));
        assertEq(verifier.defaultHash(2), _node(verifier.defaultHash(1), verifier.defaultHash(1)));
    }

    function testEmptyTree() public view {
        bytes32[] memory none = new bytes32[](0);
        (bytes32 root, uint256 bitmask, bytes32[] memory siblings) = _prove(none, none, bytes32(uint256(5)));
        assertEq(verifier.emptyRoot(), root);
        assertEq(bitmask, 0);
        assertTrue(verifier.verifyNonInclusion(root, bytes32(uint256(5)), bitmask, siblings));
    }

    function testInclusionInSmallTree() public view {
        bytes32[] memory keys = _keys(1, 2, 7, 200);
        bytes32[] memory values = _values(4);
        for (uint256 i = 0; i < 4; i++) {
            (bytes32 root, uint256 bitmask, bytes32[] memory siblings) = _prove(keys, values, keys[i]);
            assertTrue(verifier.verifyInclusion(root, keys[i], values[i], bitmask, siblings));
            assertEq(verifier.computeRoot(keys[i], _leaf(keys[i], values[i]), bitmask, siblings), root);
        }
    }

    function testNonInclusionInSmallTree() public view {
        bytes32[] memory keys = _keys(1, 2, 7, 200);
        bytes32[] memory values = _values(4);
        bytes32 absent = bytes32(uint256(3));
        (bytes32 root, uint256 bitmask, bytes32[] memory siblings) = _prove(keys, values, absent);
        assertTrue(verifier.verifyNonInclusion(root, absent, bitmask, siblings));
        assertFalse(verifier.verifyInclusion(root, absent, values[0], bitmask, siblings));
    }

    function testPresentKeyIsNotAbsentAndWrongValueFails() public view {
        bytes32[] memory keys = _keys(1, 2, 7, 200);
        bytes32[] memory values = _values(4);
        (bytes32 root, uint256 bitmask, bytes32[] memory siblings) = _prove(keys, values, keys[2]);
        assertFalse(verifier.verifyNonInclusion(root, keys[2], bitmask, siblings));
        assertFalse(verifier.verifyInclusion(root, keys[2], values[1], bitmask, siblings));
    }

    function testSiblingCountMustMatchBitmask() public {
        bytes32[] memory keys = _keys(1, 2, 7, 200);
        bytes32[] memory values = _values(4);
        (bytes32 root, uint256 bitmask, bytes32[] memory siblings) = _prove(keys, values, keys[0]);

        bytes32[] memory longer = new bytes32[](siblings.length + 1);
        for (uint256 i = 0; i < siblings.length; i++) longer[i] = siblings[i];
        vm.expectRevert(SparseMerkleVerifier.InvalidProofLength.selector);
        verifier.verifyInclusion(root, keys[0], values[0], bitmask, longer);
    }
}
