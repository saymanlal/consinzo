# Funding Rate Notes

## Why funding exists

A perpetual contract has no expiry, so nothing forces its price to converge to the spot
price. Funding is a periodic payment between the two sides: when the contract trades above
spot, longs pay shorts, which makes holding a long less attractive and pulls the price back.
The sign of the rate decides the direction of payment.

## Cumulative indices

Paying every trader each second is impossible on-chain. A cumulative index stores "quote
paid per unit of size since the market started". A position records the index when it is
opened or touched; the difference to the current index, multiplied by its size, is its
funding since then. This is the same technique as reward-per-share accounting, with a signed
value.

## Unbalanced open interest

On an order book longs and shorts always match. In designs with a pool or virtual AMM as
counterparty they do not. If both sides used the same per-unit amount, the ledger would pay
out more than it collects whenever the receiving side is larger. Splitting the collected
total across the receiving side keeps the ledger solvent without an external subsidy.

## Signed integer arithmetic

Solidity division truncates toward zero for signed integers, which rounds in different
directions for positive and negative values. Convert to unsigned magnitudes, choose the
rounding direction explicitly, then restore the sign.
