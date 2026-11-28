# Incremental Merkle Trees

## The data structure

An incremental (append-only) Merkle tree is a complete binary tree of fixed depth `d` whose
`2^d` leaves start out empty and are filled from left to right. The Ethereum deposit
contract uses one with depth 32; EIP-4881 describes how clients snapshot it.

Because all empty subtrees of the same height have the same root, those roots can be
precomputed:

```
Z[0] = 0
Z[i+1] = H(Z[i], Z[i])
```

## Insertion

```
node = leaf
for level in 0 .. d-1:
    if bit `level` of index is 0:
        filled[level] = node
        node = H(node, Z[level])
    else:
        node = H(filled[level], node)
root = node
```

## Why keep old roots

A user builds a Merkle proof off chain against the root they observed. If another insertion
lands first, the root changes and the proof no longer verifies against the current root.
Accepting any of the last `N` roots gives users a window in which their proofs remain valid
without making all historic roots valid forever.

## Hashing convention in this challenge

`H(left, right) = keccak256(abi.encodePacked(left, right))`, empty leaf `bytes32(0)`. Other
systems use different hash functions and different empty-leaf values; the structure is the
same.
