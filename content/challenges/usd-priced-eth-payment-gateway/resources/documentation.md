# Background: Pricing in USD, Settling in ETH

## Reading the feed

An ETH / USD aggregator returns `answer` such that one ETH is worth `answer / 10**decimals`
dollars. `answer` is signed and can be zero or negative when the feed misbehaves;
`updatedAt` tells you when it was last written. A consumer must reject non-positive and
out-of-date answers before using them.

## From dollars to wei

With `usd` carrying 18 decimals:

```
wei = usd * 10**decimals / answer
```

Example: 100 USD at 2,000 USD / ETH with an 8-decimal feed:
`100e18 * 1e8 / 2_000e8 = 0.05e18` wei.

Integer division truncates. When the result is an amount someone owes you, round up:
`ceil(a / b) = (a - 1) / b + 1` for `a > 0`.

## Refunds and reentrancy

Sending ETH with `call` runs the recipient's code. Anything the recipient can call back
into must already see the final state of the current operation. Update storage first, send
ETH last (checks-effects-interactions).

## Pull payments for the merchant

Instead of forwarding ETH to the merchant on every payment, the gateway records what it
owes and lets the merchant collect it. A merchant address that cannot receive ETH then
cannot block customers from paying.
