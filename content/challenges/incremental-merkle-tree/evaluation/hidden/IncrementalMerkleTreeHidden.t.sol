// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/IncrementalMerkleTree.sol";

contract IncrementalMerkleTreeHiddenTest is Test {
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
        return keccak256(abi.encodePacked("hidden-leaf", i));
    }

    function _expectedRoot(uint256 depth, uint256 filled) internal pure returns (bytes32) {
        bytes32[] memory leaves = new bytes32[](2 ** depth);
        for (uint256 i = 0; i < filled; i++) leaves[i] = _leaf(i);
        return _naiveRoot(leaves);
    }

    function testHiddenEveryRootOfDepthFourTree() public {
        IncrementalMerkleTree tree = new IncrementalMerkleTree(4, 2);
        assertEq(tree.root(), _expectedRoot(4, 0));
        for (uint256 i = 0; i < 16; i++) {
            assertEq(tree.insert(_leaf(i)), i);
            assertEq(tree.root(), _expectedRoot(4, i + 1));
        }
        vm.expectRevert(IncrementalMerkleTree.TreeFull.selector);
        tree.insert(_leaf(16));
        assertEq(tree.nextIndex(), 16);
    }

    function testHiddenDepthOne() public {
        IncrementalMerkleTree tree = new IncrementalMerkleTree(1, 1);
        bytes32 a = _leaf(1);
        bytes32 b = _leaf(2);
        tree.insert(a);
        assertEq(tree.root(), keccak256(abi.encodePacked(a, bytes32(0))));
        tree.insert(b);
        assertEq(tree.root(), keccak256(abi.encodePacked(a, b)));
        vm.expectRevert(IncrementalMerkleTree.TreeFull.selector);
        tree.insert(a);
    }

    function testHiddenHistorySizeOneKeepsOnlyCurrentRoot() public {
        IncrementalMerkleTree tree = new IncrementalMerkleTree(3, 1);
        bytes32 r0 = tree.root();
        assertTrue(tree.isKnownRoot(r0));
        tree.insert(_leaf(0));
        bytes32 r1 = tree.root();
        assertFalse(tree.isKnownRoot(r0));
        assertTrue(tree.isKnownRoot(r1));
        tree.insert(_leaf(1));
        assertFalse(tree.isKnownRoot(r1));
        assertTrue(tree.isKnownRoot(tree.root()));
    }

    function testHiddenHistoryWrapsMoreThanOnce() public {
        IncrementalMerkleTree tree = new IncrementalMerkleTree(4, 3);
        bytes32[] memory roots = new bytes32[](12);
        roots[0] = tree.root();
        for (uint256 i = 0; i < 11; i++) {
            tree.insert(_leaf(i));
            roots[i + 1] = tree.root();
            // Exactly the latest three roots are known.
            for (uint256 j = 0; j <= i + 1; j++) {
                bool expected = j + 3 > i + 1;
                assertEq(tree.isKnownRoot(roots[j]), expected);
            }
        }
        assertEq(tree.root(), roots[11]);
    }

    function testHiddenZeroRootNeverKnown() public {
        IncrementalMerkleTree tree = new IncrementalMerkleTree(2, 8);
        assertFalse(tree.isKnownRoot(bytes32(0)));
        tree.insert(_leaf(0));
        assertFalse(tree.isKnownRoot(bytes32(0)));
        assertFalse(tree.isKnownRoot(_leaf(0)));
    }

    function testHiddenZeroLeafIsAValidLeaf() public {
        IncrementalMerkleTree tree = new IncrementalMerkleTree(2, 4);
        bytes32 emptyRoot = tree.root();
        assertEq(tree.insert(bytes32(0)), 0);
        // The root is unchanged but the position is consumed.
        assertEq(tree.root(), emptyRoot);
        assertEq(tree.nextIndex(), 1);
        bytes32 x = _leaf(7);
        tree.insert(x);
        bytes32 left = keccak256(abi.encodePacked(bytes32(0), x));
        assertEq(tree.root(), keccak256(abi.encodePacked(left, tree.zeros(1))));
    }

    function testHiddenDepthThirtyTwo() public {
        IncrementalMerkleTree tree = new IncrementalMerkleTree(32, 5);
        bytes32 zero = bytes32(0);
        for (uint256 i = 0; i < 32; i++) {
            assertEq(tree.zeros(i), zero);
            zero = keccak256(abi.encodePacked(zero, zero));
        }
        assertEq(tree.zeros(32), zero);
        assertEq(tree.root(), zero);

        vm.expectRevert(IncrementalMerkleTree.InvalidLevel.selector);
        tree.zeros(33);

        // First leaf: every sibling on the path is a zero hash on the right.
        bytes32 a = _leaf(1);
        bytes32 b = _leaf(2);
        tree.insert(a);
        bytes32 node = a;
        for (uint256 i = 0; i < 32; i++) node = keccak256(abi.encodePacked(node, tree.zeros(i)));
        assertEq(tree.root(), node);

        // Second leaf: sibling of `a` at level 0, zero hashes above.
        tree.insert(b);
        node = keccak256(abi.encodePacked(a, b));
        for (uint256 i = 1; i < 32; i++) node = keccak256(abi.encodePacked(node, tree.zeros(i)));
        assertEq(tree.root(), node);
    }

    function testHiddenConstructorValidation() public {
        try new IncrementalMerkleTree(0, 4) {
            assertTrue(false, "depth 0 accepted");
        } catch (bytes memory err) {
            assertEq(bytes4(err), IncrementalMerkleTree.InvalidDepth.selector);
        }
        try new IncrementalMerkleTree(33, 4) {
            assertTrue(false, "depth 33 accepted");
        } catch (bytes memory err) {
            assertEq(bytes4(err), IncrementalMerkleTree.InvalidDepth.selector);
        }
        try new IncrementalMerkleTree(8, 0) {
            assertTrue(false, "history 0 accepted");
        } catch (bytes memory err) {
            assertEq(bytes4(err), IncrementalMerkleTree.InvalidHistorySize.selector);
        }
        IncrementalMerkleTree ok = new IncrementalMerkleTree(32, 1);
        assertEq(uint256(ok.historySize()), 1);
    }

    function testHiddenInsertionCostDoesNotGrowWithLeafCount() public {
        IncrementalMerkleTree tree = new IncrementalMerkleTree(20, 4);
        for (uint256 i = 0; i < 40; i++) tree.insert(_leaf(i));
        uint256 before = gasleft();
        tree.insert(_leaf(40));
        uint256 used = before - gasleft();
        // 20 levels of hashing and a few storage writes; far below any per-leaf loop.
        assertLt(used, 200000);
    }
}
