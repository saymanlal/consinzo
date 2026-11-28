# Bonding Curves

## What a bonding curve is

A bonding curve is a contract that mints a token when someone pays into its reserve and burns
the token when someone redeems it, at a price that is a deterministic function of the current
supply. There is no counterparty and no order book; the curve is always willing to trade.

## Linear curve

With `price(S) = b + m * S`, the cost to move the supply from `S1` to `S2` is the integral of
the price:

```
cost = b * (S2 - S1) + m * (S2^2 - S1^2) / 2
```

Equivalently, define `R(S) = b * S + m * S^2 / 2`, the total reserve backing supply `S`; then
`cost = R(S2) - R(S1)`.

## Why the formulation matters on-chain

Integer arithmetic truncates. If every trade is rounded on its own, two small buys do not cost
the same as one large buy, and the stored reserve no longer matches the curve. Expressing every
trade as a difference of the same function `R` makes the system path independent: the reserve
after any history depends only on the current supply.

## Fixed-point bookkeeping

When amounts carry 18 decimals and prices are quoted per whole token, each multiplication by an
amount introduces a factor of `1e18` that has to be divided out. The quadratic term multiplies
by the supply twice, hence the divisor `1e36`.

## Order of trades

Bonding curves are path independent in aggregate, not per user. Whoever sells first sells at the
top of the curve. An early buyer who sells after later buyers have entered makes a profit, and
the last holder to leave receives the lowest prices.
