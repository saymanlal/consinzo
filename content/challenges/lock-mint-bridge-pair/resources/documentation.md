# Background: Lock-and-Mint Bridges

## The two halves

| direction            | source chain (vault)          | destination chain (wrapped token) |
| -------------------- | ----------------------------- | --------------------------------- |
| source → destination | `lock` takes the canonical token and emits `Locked(nonce, …)` | relayer calls `mint(nonce, …)` |
| destination → source | relayer calls `release(nonce, …)` | `burn` destroys wrapped tokens and emits `Burned(nonce, …)` |

A chain cannot read another chain's state. Something off-chain has to observe the event on
one side and submit a transaction on the other. In this exercise that party is a single
trusted relayer address; production bridges replace it with a validator set, a light
client or a proof system, but the contract-level bookkeeping is the same.

## Message identity and replay

Every outgoing message gets a nonce from a counter on the chain that emits it. The
receiving side stores which nonces it has consumed. Because the two directions use
independent counters, deposit nonce 1 and burn nonce 1 are unrelated and are tracked in
different mappings on different contracts.

## The backing invariant

Wrapped supply must never exceed what the vault holds for it. With a 1:1 bridge and all
messages delivered: `wrapped.totalSupply() == vault.totalLocked()`. Between a lock and its
mint (or a burn and its release) the vault temporarily holds more than the supply, never
less.

## ERC-20 return values

EIP-20 specifies that `transfer` and `transferFrom` return a boolean. Some tokens signal
failure by returning `false` rather than reverting, so a caller must check the result.
