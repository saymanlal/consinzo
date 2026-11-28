# Reference Solution Explanation

- **Invariant**: `min <= value <= max` holds after the constructor and after every call. Every check
  in the contract relies on it.
- **Room-based comparison**: `add` checks `amount > max - value`. Because `value <= max`, the
  subtraction cannot underflow, and the comparison is safe for every `amount`. The naive
  `value + amount > max` overflows for large amounts and reverts with `Panic(0x11)` instead of
  `AboveMax`.
- **Symmetric lower bound**: `sub` checks `amount > value - min`, which also covers
  `amount > value`.
- **unchecked**: after the explicit bound check the addition and subtraction are provably safe, so
  the compiler's own overflow check is redundant and can be skipped.
- **Shared helpers**: `increment`/`decrement` delegate to the same internal functions as
  `add`/`sub`, so there is one place where the rule is enforced.

## Pitfalls

- Relying on the built-in overflow check to protect the bounds. It only protects the `uint256`
  range, not `[min, max]`, and it produces a panic rather than the required error.
- Rejecting `min == max` in the constructor. Equal bounds are valid.
- Checking the initial value before the bounds, which reports the wrong error for inverted bounds.
