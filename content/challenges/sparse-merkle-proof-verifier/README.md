# Sparse Merkle Tree Verifier: Inclusion and Non-Inclusion Proofs

## Problem Statement

A sparse Merkle tree (SMT) is a Merkle tree with one leaf for every possible key. With
32-byte keys the tree has depth 256 and 2^256 leaves, almost all of them empty. Because
every empty subtree of a given height has the same root, proofs can be compressed: only
the siblings that are *not* default hashes are transmitted. An SMT can prove that a key
maps to a value, and also that a key is absent.

Implement the stateless verifier `SparseMerkleVerifier` in `src/SparseMerkleVerifier.sol`.

## Tree Definition

- Depth 256. The leaf position of a key is `uint256(key)`.
- Height 0 is the leaf level, height 256 is the root.
- Leaf of a present key: `leafHash(key, value) = keccak256(abi.encodePacked(bytes1(0x00), key, value))`.
- Leaf of an absent key: `bytes32(0)`.
- Inner node: `nodeHash(left, right) = keccak256(abi.encodePacked(bytes1(0x01), left, right))`.
- Default hashes: `defaultHash(0) = bytes32(0)` and
  `defaultHash(h + 1) = nodeHash(defaultHash(h), defaultHash(h))`. The root of the empty
  tree is `defaultHash(256)`.
- On the way up from a leaf, at height `h` (0 to 255) the current node is the **right**
  child if bit `h` of `uint256(key)` is 1 (bit 0 is the least significant bit) and the
  left child otherwise.

## Compressed Proofs

A proof is a pair `(uint256 bitmask, bytes32[] siblings)`. For each height `h` from 0 to
255:

- if bit `h` of `bitmask` is 1, the sibling at height `h` is the next unused element of
  `siblings` (they are ordered from the leaf upwards);
- otherwise the sibling is `defaultHash(h)`.

The number of elements in `siblings` must equal the number of set bits in `bitmask`.

## Required Interface

```solidity
error InvalidProofLength();
error InvalidHeight();

function leafHash(bytes32 key, bytes32 value) external pure returns (bytes32);
function nodeHash(bytes32 left, bytes32 right) external pure returns (bytes32);
function defaultHash(uint256 height) external pure returns (bytes32);
function emptyRoot() external pure returns (bytes32);

function computeRoot(bytes32 key, bytes32 leaf, uint256 bitmask, bytes32[] calldata siblings)
    external pure returns (bytes32);
function verifyInclusion(bytes32 root, bytes32 key, bytes32 value, uint256 bitmask, bytes32[] calldata siblings)
    external pure returns (bool);
function verifyNonInclusion(bytes32 root, bytes32 key, uint256 bitmask, bytes32[] calldata siblings)
    external pure returns (bool);
```

## Rules

1. `computeRoot` folds `leaf` (an already computed leaf value) with the 256 siblings and
   returns the resulting root.
2. `verifyInclusion` returns whether the tree with root `root` maps `key` to `value`.
   Any value is allowed, including `bytes32(0)`: a key that is present with value zero is
   different from an absent key.
3. `verifyNonInclusion` returns whether `key` is absent in the tree with root `root`.
4. All three revert with `InvalidProofLength()` when the number of siblings differs from
   the number of set bits in `bitmask` (too few or too many).
5. `defaultHash` reverts with `InvalidHeight()` for `height > 256`.
6. A proof that is well formed but does not match the root makes the verify functions
   return `false`; it does not revert.

## What the Tests Check

The tests build small trees with an independent implementation, generate compressed
proofs for present and absent keys, and check acceptance and rejection: wrong values,
wrong keys, tampered siblings and bitmasks, malformed lengths, keys that differ only in
their lowest or highest bit, and the exact hash domain prefixes.
