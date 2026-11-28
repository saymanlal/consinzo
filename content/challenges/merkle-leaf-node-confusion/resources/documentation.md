# Leaf/node confusion in Merkle trees

## Second-preimage attacks

A Merkle root commits to a set of leaves. A verifier recomputes the path
`leaf -> node -> ... -> root`. If leaves and internal nodes are hashed with the same
function over inputs of the same shape, the verifier accepts an internal node as if it were
a leaf, with a shorter proof. The "leaf data" is then the concatenation of two child hashes,
which the attacker reads from the public tree.

Whether this matters depends on how leaf data is interpreted. With a 64-byte leaf made of an
index, an address and an amount, a node's preimage parses as a claim for a random address
and a random amount. Funds are lost even though the attacker does not receive them. Systems
that interpret leaves as transactions or balances have had more direct consequences.

## Domain separation

Give the two kinds of hash inputs different structure:

| Technique | Leaf | Node |
| --- | --- | --- |
| Double hashing | `H(H(data))` | `H(left ++ right)` |
| Prefix bytes (RFC 6962 style) | `H(0x00 ++ data)` | `H(0x01 ++ left ++ right)` |

Double hashing is common in Solidity because it needs no change to the node hash.

## The 64-byte rule

Avoid leaf encodings that are exactly 64 bytes before hashing when nodes are plain
`keccak256(left ++ right)`. `abi.encodePacked(uint256, address, uint96)` and
`abi.encode(a, b)` with two static 32-byte values both hit that size.

## Sorted pairs

Hashing children in ascending order removes the need for left/right flags in proofs. It
does not provide domain separation, and it means the proof does not encode the leaf's
position. Use a separate `index` in the leaf for replay protection, as this contract does.

## Checklist for airdrop contracts

- Leaves are domain-separated from nodes.
- Each leaf can be used once (bitmap or mapping keyed by a unique index).
- The leaf binds the recipient and the amount.
- The root cannot be replaced silently after claims have begun.
