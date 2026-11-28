# Reference Solution Explanation

## Constants versus immutables

- `BPS_DENOMINATOR`, `MAX_FEE_BPS` and `LOCK_PERIOD` are the same for every deployment, so they
  are `constant`. The compiler substitutes the literal wherever the name is used. No storage slot
  is reserved and reading one costs no `SLOAD`.
- `treasury`, `feeBps` and `deployedAt` differ per deployment but never change afterwards, so they
  are `immutable`. The constructor computes them and the compiler writes the values into the
  runtime bytecode. Reads are as cheap as constants.

## Constructor validation

The constructor is the only place an immutable can be assigned, which makes it the only place the
configuration can be checked. The treasury check runs first, then the fee bound, and only then are
the values assigned. `FeeTooHigh` carries both the rejected value and the limit so that a caller
can see why the deployment failed without reading the source.

## Derived views

- `feeFor` multiplies before dividing. `amount / 10_000 * feeBps` would return zero for every
  amount below 10,000 wei and lose up to 9,999 wei of precision on larger ones.
- `netAmount` is `amount - fee`, reusing the same private helper. Computing the net part with an
  independent division (`amount * (10_000 - feeBps) / 10_000`) rounds down a second time and can
  leave one wei unaccounted for.
- `isUnlocked` uses `>=`, so the contract is unlocked at exactly `unlockTime()`.

## Pitfalls

- Forgetting that `MAX_FEE_BPS` itself is a valid fee (`>` rather than `>=` in the check).
- Reading `block.timestamp` in `unlockTime()` instead of the stored `deployedAt`, which makes the
  unlock time drift forward for ever.
