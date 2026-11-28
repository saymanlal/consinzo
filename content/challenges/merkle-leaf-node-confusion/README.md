# Patch a Merkle Airdrop That Accepts Internal Nodes as Leaves

`MerkleDrop` distributes tokens according to a Merkle tree. Each entitlement is a leaf
`(index, account, amount)`; the owner publishes the root with `setRoot`, and anyone can
submit `claim(index, account, amount, proof)` to pay `amount` to `account`.

The tree is built with two public helpers:

- `leafHash(index, account, amount)` for leaves, currently
  `keccak256(abi.encodePacked(uint256 index, address account, uint96 amount))`;
- `hashPair(a, b)` for internal nodes: `keccak256` of the two children in ascending order.

The packed leaf is 32 + 20 + 12 = **64 bytes**, exactly the size of an internal node's
preimage (two 32-byte hashes). The verifier cannot distinguish them. Take any internal node
with sorted children `(lo, hi)` and read those 64 bytes as a leaf: `index = uint256(lo)`,
`account = first 20 bytes of hi`, `amount = last 12 bytes of hi`. Its hash is the node
itself, so the rest of the node's proof verifies. The claim marks a meaningless index as
used and sends a pseudo-random `uint96` amount to a pseudo-random address. Nobody profits,
but the drop's tokens are gone. This is the classic second-preimage (leaf/node confusion)
weakness of unseparated Merkle trees.

## Your task

Patch `leafHash` in `src/MerkleDrop.sol` so that a leaf hash can never equal the hash of an
internal node's preimage, for any tree depth. Requirements:

- `leafHash(index, account, amount)` stays `public pure`, deterministic, and binds all three
  fields (changing any field changes the hash).
- `leafHash(index, account, amount)` must **not** equal
  `keccak256(abi.encodePacked(index, account, amount))`. A single hash over those 64 bytes
  is the bug. Hashing the encoded leaf twice, or prefixing leaves with a domain tag so the
  preimage is not 64 bytes, are both accepted.
- `hashPair`, `verify`, `claim`, `setRoot`, errors and events keep their behaviour. In
  particular `claim` reverts with `InvalidProof()` for anything that is not a real leaf,
  `AlreadyClaimed()` for a used index, and `RootNotSet()` before the root is published.

The tests build every tree by calling `leafHash` and `hashPair` on your contract, so they
follow whatever leaf encoding you choose.

## What the tests check

Public tests perform an honest claim, a double claim, a claim with a wrong amount, and a
forged claim built from the children of an internal node. The drop is funded with
`type(uint96).max` tokens so the forged amount is always payable. Hidden tests forge from
other nodes, from the root with an empty proof and from a deeper tree, check that the leaf
hash is not the single 64-byte hash and binds every field, and cover the remaining claim and
administration paths.
