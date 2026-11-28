# Reference Solution Explanation

- **Length**: `bytes(s).length`. The conversion is a reinterpretation, not a copy. The result is
  the UTF-8 byte count, so `"é"` has length 2.
- **Equality**: lengths are compared first, then `keccak256` of both byte arrays. Hashing is the
  standard way to compare dynamic data, because `==` is not defined for `string` or `bytes`. The
  explicit length comparison is not required for correctness (different lengths give different
  hashes) but returns early without hashing.
- **Concatenation**: `string.concat` and `bytes.concat` (available since 0.8.12 and 0.8.4) build a
  new memory array. `abi.encodePacked(a, b)` produces the same bytes for two dynamic arguments.
- **Prefix test**: a longer prefix cannot match. Otherwise the leading slice
  `sBytes[:prefixLength]` is hashed and compared with the prefix. Calldata slices are views, so no
  copying happens. A byte-by-byte loop is an equally valid implementation.
- **Range checks**: both validators compute the length once and test `len < min || len > max`.
  With `min > max` the condition is true for every length, so `isLengthBetween` returns `false` and
  `validateLength` reverts with the custom error, without any subtraction that could underflow.

## Pitfalls

- Treating the byte length as a character count when validating user-visible limits.
- Comparing only hashes of fixed-size truncations (for example casting to `bytes32`), which makes
  long strings with a common 32-byte prefix look equal.
- Implementing `startsWith` by indexing `s` without checking that the prefix is not longer, which
  panics with an out-of-bounds access.
- Writing the range check as `len - min <= max - min`, which underflows.
