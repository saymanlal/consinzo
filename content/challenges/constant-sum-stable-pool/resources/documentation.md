# Constant-Sum Market Makers

## The invariant

A constant-product pool keeps `x * y = k` and its price moves with every trade. A constant-sum
pool keeps `x + y = k`: one unit in, one unit out, at any size, with zero price impact. This is
attractive for assets that should trade at par, for example two representations of the same
currency.

The cost of zero price impact is that the pool cannot defend itself. Whenever the market values
one token below the other, traders deposit the cheaper one and remove the dearer one until none
is left. The pool then consists of a single token.

## Fees

A fee of `f` on the input means the trader receives `amountIn * (1 - f)`. Because the fee is
retained, the sum of the reserves grows with each trade. Liquidity providers own the reserves
pro rata, so the fee is distributed to them automatically, without any per-provider accounting.

## Liquidity shares

Providers receive shares; `totalSupply` shares own both reserves. To keep this fair:

- deposits after the first are made in the ratio of the current reserves;
- withdrawals return the same fraction of each reserve.

Every division has a direction. Mint fewer shares rather than more, pull more tokens rather
than fewer, pay out fewer tokens rather than more. Then the value per share is monotonic.

## Things that differ from constant-product pools

- A reserve can be exactly zero, so ratios with that reserve in the denominator are undefined.
- There is no `sqrt` in the first deposit: the natural unit of liquidity is the sum of the
  deposited amounts.
- Swap output is bounded by the reserve, not by an asymptote, so an explicit liquidity check is
  required.
