# Sparse Merkle Trees

## Idea

Fix the tree depth to the key length (256 bits here). Every key has exactly one leaf
position, so the tree is a map with an authenticated root. The tree is far too large to
materialise, but almost all of it is empty, and empty subtrees of equal height share one
root:

```
D[0] = 0
D[h+1] = H(D[h], D[h])
```

Only the paths to the present keys contain anything else.

## Proofs

A full proof for one key is 256 siblings. For a tree with `n` random keys only about
`log2(n)` of them differ from the default hashes. The compressed form used here sends a
256-bit mask that marks the non-default heights, plus just those siblings.

## Non-inclusion

In an ordinary Merkle tree (a list of leaves) there is no simple way to prove that a value
is not included. In a sparse Merkle tree each key has a fixed position, so "the leaf at
position `k` is empty" is a normal path proof. This is what makes SMTs suitable for
nullifier sets, revocation lists and account state.

## Domain separation

Leaves and inner nodes must hash differently (prefix bytes `0x00` and `0x01` here, as in
RFC 6962). Otherwise the concatenation of two children could be reinterpreted as leaf
contents, a second-preimage attack on the tree structure.

## Relation to Ethereum's state trie

Ethereum uses a Merkle Patricia trie rather than a binary SMT, and `eth_getProof`
(EIP-1186) returns proofs for it. The principle is the same: the proof contains the nodes
along the path of the hashed key, and absence is shown by a path that ends without
reaching a matching leaf.
