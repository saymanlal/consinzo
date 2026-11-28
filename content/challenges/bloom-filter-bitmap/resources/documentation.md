# Bloom Filters

## Guarantees

- **No false negatives.** An item that was added always has all of its bits set, because
  bits are never cleared.
- **False positives are possible.** Bits set by other items can happen to cover all `k`
  positions of an item that was never added.

Items cannot be removed: clearing a bit could remove other items that share it.

## Choosing m and k

With `m` bits, `k` hash functions and `n` inserted items, the probability that a given bit
is still zero is about `e^(-kn/m)`, so the false-positive rate is about

```
p = (1 - e^(-kn/m))^k
```

For a given `m` and `n` the rate is lowest near `k = (m / n) * ln 2`.

## Deriving k hash functions

This challenge derives the functions by hashing the item together with a one-byte index:
`keccak256(abi.encodePacked(item, uint8(i)))`. Each index gives an independent 256-bit
value, which is reduced modulo `m`.

## Bitmaps in the EVM

A storage slot holds 256 bits, so a bitmap of `m` bits needs `ceil(m / 256)` slots.
`n >> 8` selects the slot and `1 << (n & 0xff)` the bit. Setting several bits that fall
into the same slot costs one cold access and cheap warm accesses afterwards.

Ethereum block headers contain a 2048-bit Bloom filter over log addresses and topics that
uses three positions per entry; light clients use it to skip blocks that cannot contain
the logs they are looking for.
