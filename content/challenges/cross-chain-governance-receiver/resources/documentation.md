# Background: Governing Contracts on Another Chain

## The shape of the system

```
home chain                             this chain
┌──────────┐   message    ┌───────────┐  receiveMessage  ┌────────────────────┐
│ governor │ ───────────▶ │ messenger │ ───────────────▶ │ GovernanceReceiver │ ──▶ targets
└──────────┘   (bridge)   └───────────┘                  └────────────────────┘
```

The receiver owns the protocol contracts on its chain. The governor never calls them
directly; it sends a message describing calls for the receiver to make.

## Origin authentication

A messaging endpoint delivers messages from *anyone* on *any* supported chain. It reports
where each message came from; filtering is the receiver's job:

1. the caller must be the endpoint (otherwise the origin fields are just arguments an
   attacker typed in);
2. the reported chain must be the home chain;
3. the reported sender must be the governor.

EIP-5164 describes this dispatcher/executor split and the same three checks.

## Why a timelock on the receiving side

The delay gives users of the remote deployment time to react to a proposal and gives a
guardian time to cancel a message that should not have been sent (for example after a
bridge incident). The grace period bounds how long a queued proposal stays executable, so
old proposals cannot be executed in a context nobody anticipated.

## Hash commitments

Storing arrays of calldata is expensive. A common alternative is to store a hash and ask
the executor to provide the preimage. Use `abi.encode` for the hash: it encodes lengths and
offsets, so different lists never produce the same bytes.

## Low-level calls

`target.call{value: v}(data)` returns `(bool success, bytes returndata)` and does not
revert on failure. The caller must check `success`. Sending value draws from the calling
contract's balance, so the receiver needs a `receive()` function to be funded.
