# Reference Solution Explanation

## Data model

A route is keyed by `(local token, destination chain)` and stores the remote token id and
the fee. A reverse map `localTokenOf[chainId][remoteToken]` lets an inbound message, which
only knows the remote id, find the local token. `registerRoute` keeps both maps consistent
and refuses a remote id that is already mapped on that chain, so the reverse lookup is
never ambiguous.

Two books are kept per route:

- `lockedLiquidity` – the net amount sent to that chain and not yet returned;
- `accruedFees` – fees taken on that route and not yet withdrawn.

Every token unit the router holds belongs to exactly one of these books, which gives the
invariant `balance >= sum(locked) + sum(fees)`.

## Outbound

`bridgeOut` measures the balance difference around `transferFrom` instead of trusting the
`amount` argument. With a fee-on-transfer token the argument overstates what arrived; if
the books used it, the route would owe more than the router holds and the last users to
bridge back would not be paid. The fee is computed on the received amount and rounds down.

## Inbound

`bridgeIn` is limited by the route's own `lockedLiquidity`, not by the router's token
balance. This is the property that isolates routes: a compromised or buggy remote chain can
at most take back what was sent to it. It also keeps fees out of reach of inbound
transfers. Replay protection is a `(chainId, nonce)` bitmap rather than a counter, so
messages can be delivered out of order.

State is updated before the token transfer in both `bridgeIn` and `withdrawFees`.

## Pitfalls

- Checking `amount <= token.balanceOf(address(this))` on release. This passes the basic
  tests and breaks route isolation.
- Paying `withdrawFees` from the balance instead of from the per-route fee book.
- One global nonce for all destination chains, or a replay map keyed by nonce only.
- Allowing the same remote token id to be registered for two local tokens on one chain.
