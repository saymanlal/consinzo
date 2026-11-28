# Background: Canonical Token Mappings and Route Accounting

## Canonical mappings

A token that exists on several chains is represented by different contracts on each. A
bridge needs an authoritative table that says which remote contract corresponds to a local
one. Two properties matter:

- **Functional**: a `(local token, chain)` pair has at most one remote token.
- **Injective per chain**: on one chain, a remote token belongs to at most one local token.

Remote identifiers are stored as `bytes32` so that non-EVM address formats also fit.

## Why per-route books

A lock-and-release bridge holds tokens that back claims on other chains. If the bridge
serves chains A and B from one pool, a forged message from B can release tokens that back
holders on A. Recording how much was locked towards each chain, and refusing to release
more than that, limits the damage of a faulty remote chain to its own route.

## Fees

Fees are usually quoted in basis points (1 bps = 0.01%). `fee = amount * bps / 10_000`
truncates, so very small transfers may pay no fee. Fees must be tracked separately from
locked liquidity; otherwise withdrawing fees can remove tokens that back user claims.

## Measuring received amounts

`transferFrom(from, to, amount)` does not guarantee that `to` receives `amount`. Reading
the balance before and after the call gives the amount that actually arrived.

## Nonces

Outbound transfers carry a nonce so the remote side can tell messages apart. Inbound
messages are recorded as processed by `(source chain, nonce)`, which rejects replays
without requiring in-order delivery.
