# Reference Solution Explanation

- **Validation**: a rate above `10_000` bps would mean more than 100%. All three functions go
  through `_mulBps`, which rejects it with `InvalidBps(bps)`.
- **Decomposition**: with `D = 10_000`, write `amount = q * D + r`. Then
  `amount * bps / D = q * bps + (r * bps) / D`. The first term is an integer, so the fractional part
  of the result comes entirely from `(r * bps) / D`, and `r * bps` is below `1e8`. No intermediate
  value exceeds `amount`, so the function is exact and overflow-free for the whole `uint256` range.
- **Rounding**: floor is plain integer division of the small term. Ceiling adds one when that
  division leaves a remainder.
- **splitFee**: the fee is rounded up and `net = amount - fee`. Since `fee <= amount`, the
  subtraction is safe, and the two parts always sum to the input.

## Why the naive version is not enough

`amount * bps / 10_000` reverts with `Panic(0x11)` once `amount` exceeds
`type(uint256).max / bps`. For 18-decimal tokens that limit is far away, but a general-purpose
helper should not carry a hidden input limit.

## Pitfalls

- Rounding up with `(amount * bps + 9_999) / 10_000`, which overflows even earlier.
- Rounding up unconditionally by adding one, which is wrong when the division is exact.
- Computing `net` with `mulBpsDown(amount, 10_000 - feeBps)` and `fee` independently is correct
  here, but computing both with the same rounding direction breaks `fee + net == amount`.
