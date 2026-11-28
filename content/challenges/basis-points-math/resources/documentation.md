# Basis Points and Rounding: Background

## Basis points

Fees and rates on chain are usually integers in basis points: `1 bps = 0.01%`, `100 bps = 1%`,
`10_000 bps = 100%`. A percentage of an amount is `amount * bps / 10_000`.

## Integer division

Solidity integer division truncates towards zero; for unsigned numbers that is the floor.
`7 / 2 == 3` and `7 % 2 == 1`. There are no fractional types, so the remainder is dropped unless
the code handles it.

## Rounding direction is a design decision

Whoever benefits from the dropped remainder should be chosen deliberately. The usual rule is to
round in favour of the protocol and against the caller: fees round up, payouts round down. If the
rounding favours the caller, repeating a small operation many times can extract value.

Ceiling division of `x / d`:

```solidity
uint256 result = x / d;
if (x % d != 0) result += 1;
```

## Multiply before divide, and its limit

`amount / 10_000 * bps` loses precision because the division happens first.
`amount * bps / 10_000` is precise but the product can exceed 256 bits. Splitting the amount into
quotient and remainder keeps full precision with small intermediates:

```
amount = q * D + r
amount * bps / D = q * bps + (r * bps) / D
```

## Conservation

When one amount is split into parts, compute all but one part and obtain the last by subtraction.
That guarantees the parts sum to the original and no unit is lost or created.
