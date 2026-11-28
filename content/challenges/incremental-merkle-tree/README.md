# Append-Only Incremental Merkle Tree with Root History

## Problem Statement

Deposit contracts, mixers and message bridges keep a Merkle tree of all entries on chain,
but they cannot afford to store or rehash the whole tree. An incremental Merkle tree fixes
the depth, fills leaves from left to right and stores only one node per level, which is
enough to compute the new root after every insertion.

Implement `IncrementalMerkleTree` in `src/IncrementalMerkleTree.sol`.

## Required Interface

```solidity
error InvalidDepth();
error InvalidHistorySize();
error InvalidLevel();
error TreeFull();

event LeafInserted(uint256 indexed index, bytes32 leaf, bytes32 newRoot);

constructor(uint8 depth_, uint32 historySize_);

function depth() external view returns (uint8);
function historySize() external view returns (uint32);
function nextIndex() external view returns (uint256);
function zeros(uint256 level) external view returns (bytes32);
function root() external view returns (bytes32);
function isKnownRoot(bytes32 candidate) external view returns (bool);
function insert(bytes32 leaf) external returns (uint256 index);
```

## Rules

1. The tree has `2 ** depth` leaves. `depth_` must be between 1 and 32, otherwise the
   constructor reverts with `InvalidDepth()`. `historySize_` must be at least 1, otherwise
   it reverts with `InvalidHistorySize()`.
2. An empty leaf has the value `bytes32(0)`. A parent node is
   `keccak256(abi.encodePacked(left, right))`.
3. `zeros(level)` is the root of an empty subtree of height `level`: `zeros(0) = bytes32(0)`
   and `zeros(i + 1) = keccak256(abi.encodePacked(zeros(i), zeros(i)))`. It is defined for
   `level <= depth` and reverts with `InvalidLevel()` above that.
4. `insert` places `leaf` at position `nextIndex`, returns that position, increases
   `nextIndex` by one and emits `LeafInserted`. It reverts with `TreeFull()` once all
   `2 ** depth` positions are used. Any `bytes32` value is accepted as a leaf.
5. `root()` is the Merkle root of the full tree in which all positions that have not been
   filled are empty leaves. Before the first insertion it equals `zeros(depth)`.
6. The contract remembers the most recent `historySize` roots, including the current one.
   The root of the empty tree counts as the first root. `isKnownRoot(candidate)` is true
   exactly for the roots in this window. `isKnownRoot(bytes32(0))` is always false.
7. An insertion must not loop over the leaves: its cost has to be proportional to `depth`.

## What the Tests Check

- Roots after each insertion against an independent full-tree computation.
- The zero hashes, the full-tree condition and the constructor argument checks.
- The history window: which roots are known after more insertions than `historySize`.
