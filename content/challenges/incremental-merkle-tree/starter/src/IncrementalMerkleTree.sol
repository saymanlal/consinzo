// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract IncrementalMerkleTree {
    error InvalidDepth();
    error InvalidHistorySize();
    error InvalidLevel();
    error TreeFull();

    event LeafInserted(uint256 indexed index, bytes32 leaf, bytes32 newRoot);

    uint8 public immutable depth;
    uint32 public immutable historySize;
    uint256 public nextIndex;

    // TODO: declare storage for the zero hashes, one cached node per level and the root history.

    constructor(uint8 depth_, uint32 historySize_) {
        // TODO: validate the arguments (InvalidDepth, InvalidHistorySize).
        // TODO: precompute the zero hashes and record the root of the empty tree.
        depth = depth_;
        historySize = historySize_;
    }

    function zeros(uint256 level) external view returns (bytes32) {
        // TODO: revert with InvalidLevel when level > depth.
        revert("NOT_IMPLEMENTED");
    }

    function root() external view returns (bytes32) {
        // TODO
        revert("NOT_IMPLEMENTED");
    }

    function isKnownRoot(bytes32 candidate) external view returns (bool) {
        // TODO: true for the latest `historySize` roots, never for bytes32(0).
        return false;
    }

    function insert(bytes32 leaf) external returns (uint256 index) {
        // TODO: revert with TreeFull when the tree has no free position.
        // TODO: recompute the root in `depth` steps and push it into the history.
        revert("NOT_IMPLEMENTED");
    }
}
