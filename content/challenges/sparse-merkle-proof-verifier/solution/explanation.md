# Reference Solution Explanation

## One fold for both kinds of proof

`computeRoot` starts from a leaf value and walks up 256 levels. At height `h`:

1. The sibling is taken from `siblings` if bit `h` of the bitmask is set, otherwise it is
   the default hash of height `h`.
2. Bit `h` of the key decides the order: `nodeHash(sibling, node)` if the bit is 1 (the
   node is a right child), `nodeHash(node, sibling)` otherwise.
3. The running default hash is advanced with `nodeHash(d, d)`.

`verifyInclusion` calls it with `leafHash(key, value)`, `verifyNonInclusion` with the
empty leaf `bytes32(0)`. Nothing else differs: absence of a key is the statement "the leaf
at this position is empty".

## Length checks

A set bit with no sibling left reverts immediately. After the loop, leftover siblings
revert as well. Accepting unused trailing siblings would allow many different encodings of
the same proof, which breaks systems that deduplicate or hash proofs.

## Hashing

`leafHash` prefixes `0x00`, `nodeHash` prefixes `0x01`. Without the prefixes an attacker
could present the 64 bytes of an inner node as a `(key, value)` pair, or a leaf as an
inner node. `nodeHash` is written in assembly and hashes 65 bytes placed behind the free
memory pointer without moving it; a proof needs 512 of these hashes, so avoiding 512
allocations keeps memory flat.

## Pitfalls

- Treating a present key with value zero as absent. The present leaf is
  `leafHash(key, 0)`, which is not zero.
- Reading key bits from the most significant end. This challenge defines bit 0 (least
  significant) as the leaf level.
- Using `defaultHash(h)` computed from scratch at every level, which is quadratic. Carry
  it along instead.
- Returning `false` for malformed lengths in one function and reverting in another.

## Cost

About 512 keccak calls and 256 loop iterations, independent of how many keys the tree
holds.
