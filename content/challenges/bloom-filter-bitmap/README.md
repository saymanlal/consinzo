# Bloom Filter with k Hash Functions over a Bitmap

## Problem Statement

A Bloom filter answers "have I seen this item?" with a fixed amount of storage. It keeps a
bitmap of `m` bits. Adding an item sets `k` bits chosen by `k` hash functions. An item
*might* be in the set when all of its `k` bits are set, and is *definitely not* in the set
when at least one of them is clear.

Implement `BloomFilter` in `src/BloomFilter.sol`.

## Required Interface

```solidity
error InvalidParameters();
error InvalidHashIndex();
error IndexOutOfRange();

event ItemAdded(bytes32 indexed item, bool changed);

constructor(uint256 bitCount_, uint8 hashCount_);

function bitCount() external view returns (uint256);   // m
function hashCount() external view returns (uint8);    // k
function setBits() external view returns (uint256);    // number of bits currently set

function bitIndex(bytes32 item, uint8 i) external view returns (uint256);
function add(bytes32 item) external returns (bool changed);
function mightContain(bytes32 item) external view returns (bool);
function bitAt(uint256 index) external view returns (bool);
function word(uint256 wordIndex) external view returns (uint256);
```

## Rules

1. The constructor reverts with `InvalidParameters()` when `bitCount_` is 0, when
   `hashCount_` is 0 or when `hashCount_` is greater than 16.
2. The `i`-th hash function (for `0 <= i < k`) maps an item to the bit

   ```
   bitIndex(item, i) = uint256(keccak256(abi.encodePacked(item, uint8(i)))) % bitCount
   ```

   `bitIndex` reverts with `InvalidHashIndex()` when `i >= hashCount`.
3. Bits are packed 256 per word. Bit `n` is stored in word `n / 256` at bit position
   `n % 256`, where position 0 is the least significant bit. `word(wordIndex)` returns the
   raw word; words that hold no bits of the filter read as 0.
4. `add(item)` sets the `k` bits of the item. It returns `true` if at least one bit changed
   from 0 to 1 and `false` if all of them were already set. It emits `ItemAdded`.
5. `setBits()` is the exact number of bits that are 1. A bit is counted once, no matter how
   many items or hash functions map to it.
6. `mightContain(item)` is `true` exactly when all `k` bits of the item are set.
7. `bitAt(index)` returns the value of one bit and reverts with `IndexOutOfRange()` when
   `index >= bitCount`.

## What the Tests Check

- Bit positions against the formula, including bitmaps that span several words and bit
  counts that are not multiples of 256.
- No false negatives, the return value of `add`, and the `setBits` counter when positions
  collide.
- A constructed false positive, and the revert conditions.
