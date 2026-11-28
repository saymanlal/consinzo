# Reference Solution Explanation

The filter stores its bits in `mapping(uint256 => uint256)`, 256 bits per word. For a bit
number `n` the word is `n >> 8` and the mask is `1 << (n & 0xff)`.

- `add` computes the `k` positions one after another. For each one it reads the word from
  storage, and only if the bit is clear it writes the word back and increments a local
  counter. Reading the word fresh in every round matters: two hash functions can map one
  item to the same bit, and a cached copy of the word would count that bit twice.
- `setBits` is increased once by the number of bits that really changed, and `changed`
  is true when that number is non-zero.
- `mightContain` returns false at the first clear bit.
- `bitAt` bounds-checks against `bitCount`; `word` exposes the raw storage word.

## Pitfalls

- Incrementing `setBits` by `k` on every successful add, or once per hash function
  without checking whether the bit was already set.
- Computing the modulus over the number of words, or over a rounded-up multiple of 256,
  instead of over `bitCount`.
- Hashing `abi.encode(item, i)` instead of the packed form; the positions then differ from
  the specification.
- Returning `changed = true` only when all `k` bits were new. One new bit is enough.

## Complexity

`add` costs at most `k` hashes, `k` storage reads and `k` storage writes. `mightContain`
costs at most `k` hashes and reads.
