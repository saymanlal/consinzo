# Precision Loss from Division Before Multiplication

Solidity has no fractional numbers. `a / b` on integers returns the floor of the quotient,
and the remainder is lost. When a division is followed by a multiplication, the lost
remainder is multiplied too, so the error grows from "less than one unit" to "up to one
multiplier's worth".

```
amount / 10_000 * feeBps     // error up to feeBps - 1 units, and 0 below 10_000
amount * feeBps / 10_000     // error below 1 unit
```

## Rules of thumb

- Do all multiplications before any division.
- Decide deliberately which party the final rounding favours, and document it. Protocol
  fees usually round down or up consistently, never "sometimes".
- Check the size of intermediate products. If they can exceed 2^256, use a 512-bit
  `mulDiv` routine instead of reordering back to the lossy form.
- Test with values that are not round: one unit below a boundary, primes, and amounts
  smaller than the denominator.

## Basis points

One basis point is 1/10 000. A fee of `feeBps` on `amount` is
`amount * feeBps / 10_000`. Hidden division-first bugs often appear when the denominator
is written as a constant on the left for "readability".
