# Reference Solution Explanation

## Root cause

A Merkle proof only shows that *some* 32-byte value hashes up to the root. Whether that
value is a leaf or an internal node is decided by convention. Here both were produced the
same way: `keccak256` over 64 bytes.

```
node = keccak256(lo ++ hi)                         // 32 + 32 bytes
leaf = keccak256(index ++ account ++ amount)       // 32 + 20 + 12 bytes
```

Choosing `index = lo`, `account = hi[0:20]`, `amount = hi[20:32]` makes `leafHash` return
the node. Supplying the node's sibling path as the proof makes `verify` succeed. The claim
then transfers `amount` to `account`. With a well-funded drop, about half of all nodes yield
an amount below `2**95`, and an attacker can pick the node (or grind the tree) to drain a
chosen share of the balance.

## Fix

```solidity
return keccak256(bytes.concat(keccak256(abi.encode(index, account, amount))));
```

The outer hash takes a 32-byte input, while every node hash takes a 64-byte input. For a
node to equal a leaf, two different-length preimages would have to collide under
`keccak256`. The inner `abi.encode` pads each field to 32 bytes, which also removes any
ambiguity between adjacent packed fields. This is the convention used by the common
JavaScript Merkle tree libraries, so off-chain tooling stays simple.

Nothing else changes: `hashPair`, `verify` and `claim` are correct once leaves live in
their own domain.

## Alternatives and pitfalls

- A domain tag works too: `keccak256(abi.encodePacked(bytes1(0x00), ...))` for leaves, as
  long as node preimages cannot have the same length and prefix.
- Range-checking `index` makes forged claims unlikely but keeps the structural flaw.
- Checking `proof.length` against a fixed depth blocks this forgery for balanced trees, but
  couples the contract to one tree shape.
- Changing the leaf format changes the root. A deployed drop needs a new root built with the
  new `leafHash`.
