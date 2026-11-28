// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/IncrementalMerkleTree.sol";

contract IncrementalMerkleTreeTest is Test {
    IncrementalMerkleTree public tree;
    uint8 internal constant DEPTH = 3;

    function setUp() public {
        tree = new IncrementalMerkleTree(DEPTH, 4);
    }

    /// Reference: hash the complete tree level by level. `leaves` must have 2**depth entries.
    function _naiveRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
        uint256 n = leaves.length;
        while (n > 1) {
            for (uint256 i = 0; i < n / 2; i++) {
                leaves[i] = keccak256(abi.encodePacked(leaves[2 * i], leaves[2 * i + 1]));
            }
            n /= 2;
        }
        return leaves[0];
    }

    function _leaf(uint256 i) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("leaf", i));
    }

    function _expectedRoot(uint256 filled) internal pure returns (bytes32) {
        bytes32[] memory leaves = new bytes32[](2 ** DEPTH);
        for (uint256 i = 0; i < filled; i++) leaves[i] = _leaf(i);
        return _naiveRoot(leaves);
    }

    function testEmptyTree() public view {
        assertEq(uint256(tree.depth()), 3);
        assertEq(tree.nextIndex(), 0);
        assertEq(tree.zeros(0), bytes32(0));
        assertEq(tree.zeros(1), keccak256(abi.encodePacked(bytes32(0), bytes32(0))));
        assertEq(tree.root(), _expectedRoot(0));
        assertEq(tree.root(), tree.zeros(3));
        assertTrue(tree.isKnownRoot(tree.root()));
    }

    function testInsertUpdatesRoot() public {
        for (uint256 i = 0; i < 5; i++) {
            uint256 index = tree.insert(_leaf(i));
            assertEq(index, i);
            assertEq(tree.nextIndex(), i + 1);
            assertEq(tree.root(), _expectedRoot(i + 1));
        }
    }

    function testTreeFullReverts() public {
        for (uint256 i = 0; i < 8; i++) tree.insert(_leaf(i));
        assertEq(tree.root(), _expectedRoot(8));

        vm.expectRevert(IncrementalMerkleTree.TreeFull.selector);
        tree.insert(_leaf(8));
    }

    function testRootHistoryWindow() public {
        bytes32 emptyRoot = tree.root();
        tree.insert(_leaf(0));
        bytes32 r1 = tree.root();
        tree.insert(_leaf(1));
        tree.insert(_leaf(2));
        // Window of 4: empty, r1, r2, r3.
        assertTrue(tree.isKnownRoot(emptyRoot));
        assertTrue(tree.isKnownRoot(r1));

        tree.insert(_leaf(3));
        // Window of 4: r1, r2, r3, r4. The empty root has been evicted.
        assertFalse(tree.isKnownRoot(emptyRoot));
        assertTrue(tree.isKnownRoot(r1));
        assertTrue(tree.isKnownRoot(tree.root()));
        assertFalse(tree.isKnownRoot(bytes32(0)));
    }
}
