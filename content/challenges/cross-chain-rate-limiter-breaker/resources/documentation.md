# Background: Rate Limits and Circuit Breakers for Bridges

## Token bucket

A token bucket has a capacity `C` and a refill rate `r`. It starts full. Sending `x` units
requires `x` tokens. Tokens come back at `r` per second up to `C`. Over any period of
length `t` the bucket lets through at most `C + r * t`.

On-chain there is no clock tick, so the bucket is updated lazily: store the content and
the time of the last update, and compute the current content from elapsed time whenever
it is needed.

## Fixed-window counter

A fixed-window counter adds up events in `[start, start + w)` and compares the sum with a
threshold. When a request arrives after the window has ended, a new window begins. It is
cheaper than a true sliding window and good enough for a safety net whose job is to stop
a drain, not to shape traffic.

## Why both

The bucket bounds the rate but is satisfied by an attacker who patiently takes the
maximum every time it refills. The breaker looks at the total over a longer period and,
unlike the bucket, does not recover by itself: it requires a privileged account to
confirm that the outflow was legitimate. Typical settings make the threshold larger than
the bucket capacity but smaller than what the bucket would allow over the whole window.

## State changes and reverts

Everything a transaction writes is discarded if it reverts. A safety mechanism that needs
to remember "something bad was attempted" cannot signal it by reverting. It must commit
the state change and tell the caller through a return value.

## Asymmetric permissions

Stopping a route is safe and may need to happen quickly, so it is often delegated to a
guardian key or a bot. Restarting a route can release funds and is reserved for the
owner.
