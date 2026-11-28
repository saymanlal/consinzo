# Reference Solution Explanation

## Lazy token bucket

The bucket is never updated by a timer. It stores `tokens` as of `lastRefill`, and the
current content is derived on demand:

```
min(capacity, tokens + (now - lastRefill) * refillPerSecond)
```

`_currentTokens` computes this in `uint256`. Elapsed time fits in 64 bits and the rate in
128, so the product fits in 192 bits and the sum cannot overflow, whatever the owner
configures. Every function that changes the bucket writes the derived value back together
with `lastRefill = now`.

## Re-configuration

`configureRoute` on an existing route first materialises the bucket under the old
parameters and only then overwrites them. If it stored the new rate and left `lastRefill`
alone, the next read would apply the new rate to time that passed under the old one: a
route idle for an hour would be credited an hour at the new rate. The content is also
capped at the new capacity so that shrinking a route takes effect at once.

## Breaker window

The breaker uses a fixed window that is restarted lazily: when a `consume` arrives at or
after `windowStart + breakerWindow`, the window is reset to start at that moment. The view
`windowOutflow` applies the same expiry rule without writing.

Order of checks in `consume`: pause flag, bucket, breaker. The bucket comes before the
breaker so that requests which could not have been served anyway do not pause the route;
only value that would really have left counts as abnormal outflow.

## A trip must persist

On a trip, `consume` writes `paused = true` and **returns** `false`. A revert would undo
the write, and the caller could retry with an amount just under the threshold, never
getting paused. This is also why the function returns `false` rather than reverting for
the other limit conditions: the bridge needs one uniform, non-reverting answer.

The tripping request itself is not taken from the bucket and not added to the outflow.

## Gross outflow

`replenish` credits the bucket but does not touch `windowOutflow`. If inbound transfers
reduced the counted outflow, an attacker who controls the inbound side (a forged message,
for example) could reset the breaker at will. `replenish` also has to cope with any
`uint256` amount, so the sum is compared with the capacity before being narrowed to
`uint128`.

## Unpausing

Only the owner can unpause, and doing so starts a fresh window. Without the reset, the
outflow that tripped the breaker would still be counted and the first transfer after the
review would trip it again.

## Pitfalls

- Reverting on a trip.
- Applying a new refill rate retroactively.
- `uint128(tokens + amount)` in `replenish` truncating a huge amount.
- Using `>` instead of `>=` for window expiry, or `>=` instead of `>` for the threshold.
- Resetting the breaker's outflow on inbound transfers.
