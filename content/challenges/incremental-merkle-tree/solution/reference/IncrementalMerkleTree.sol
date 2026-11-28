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

    // _zeros[i] is the root of an empty subtree of height i (0 <= i <= depth).
    mapping(uint256 => bytes32) private _zeros;
    // _filled[i] is the most recent left child seen at level i. It is only read when the
    // node being hashed at level i is a right child, in which case it is its sibling.
    mapping(uint256 => bytes32) private _filled;
    // Ring buffer of the latest `historySize` roots; _cursor points at the newest.
    mapping(uint256 => bytes32) private _roots;
    uint32 private _cursor;

    constructor(uint8 depth_, uint32 historySize_) {
        if (depth_ == 0 || depth_ > 32) revert InvalidDepth();
        if (historySize_ == 0) revert InvalidHistorySize();
        depth = depth_;
        historySize = historySize_;

        bytes32 zero = bytes32(0);
        for (uint256 i = 0; i < depth_; ++i) {
            _zeros[i] = zero;
            zero = _hashPair(zero, zero);
        }
        _zeros[depth_] = zero;
        _roots[0] = zero; // the empty tree is the first root in the history
    }

    function zeros(uint256 level) external view returns (bytes32) {
        if (level > depth) revert InvalidLevel();
        return _zeros[level];
    }

    function root() public view returns (bytes32) {
        return _roots[_cursor];
    }

    function isKnownRoot(bytes32 candidate) external view returns (bool) {
        // Unused ring slots hold zero, so zero must never be reported as known.
        if (candidate == bytes32(0)) return false;
        uint256 size = historySize;
        for (uint256 i = 0; i < size; ++i) {
            if (_roots[i] == candidate) return true;
        }
        return false;
    }

    function insert(bytes32 leaf) external returns (uint256 index) {
        index = nextIndex;
        uint256 levels = depth;
        if (index == uint256(1) << levels) revert TreeFull();

        bytes32 node = leaf;
        uint256 position = index;
        for (uint256 i = 0; i < levels; ++i) {
            if (position & 1 == 0) {
                // Left child: everything to its right is still empty. Cache it so that the
                // next insertion in this subtree can use it as its left sibling.
                _filled[i] = node;
                node = _hashPair(node, _zeros[i]);
            } else {
                // Right child: the left sibling is the cached, already completed subtree.
                node = _hashPair(_filled[i], node);
            }
            position >>= 1;
        }

        uint32 cursor = (_cursor + 1) % historySize;
        _cursor = cursor;
        _roots[cursor] = node;
        nextIndex = index + 1;

        emit LeafInserted(index, leaf, node);
    }

    function _hashPair(bytes32 left, bytes32 right) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(left, right));
    }
}
