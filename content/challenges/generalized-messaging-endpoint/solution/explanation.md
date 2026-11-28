# Reference Solution Explanation

## Identity of a message

`packetId` hashes every field of the packet, with the payload reduced to its hash. The
`ordered` flag is part of the id, so an ordered and an unordered message with the same
nonce between the same applications are different messages. `status[id]` is the single
source of truth for what happened to a message:

```
None --deliver ok--> Delivered
None --deliver fails--> Failed --retry ok--> Delivered
                           |
                           +--skip (receiver)--> Skipped
```

`Delivered` and `Skipped` are terminal. Because `retry` and `skip` look the message up by
the id of the packet they are given, a caller cannot retry a failed message with a
different payload: the id would not match any `Failed` entry.

## Sending

Outbound nonces live in a four-level mapping `(sender, dstChainId, receiver, ordered)`.
`send` follows checks-effects-interactions strictly: quote, validate, take the nonce, book
the fee, emit, and only then refund the excess. The refund is the one external call and
its target is chosen by the sender, so it must be assumed hostile. By the time it runs,
nothing about the outer message is still pending, and a nested `send` just takes the next
nonce and books its own fee. `collectedFees` grows by the quoted fee only, so the
endpoint's balance always equals `collectedFees`.

`send` is deliberately outside the delivery lock. Request/response applications reply from
inside `onMessage`; a global lock would make that impossible.

## Delivering

Validation order: relayer, chain, replay, then for ordered packets blocked-channel and
nonce. The ordered nonce is consumed before the receiver is called.

A receiver failure is recorded, not propagated. If `deliver` reverted on failure:

- on an ordered channel the nonce would not advance and the relayer would be stuck
  retrying a message it cannot fix;
- a receiver could grief the relayer for gas indefinitely.

Recording `Failed` hands the problem to the application: anyone can `retry`, and the
receiver can `skip`. For ordered channels `blockedBy` holds the id of the failed message
and later packets are refused until it is resolved, which preserves ordering semantics
without holding up any other channel.

`retry` writes the success state first and reverts with `RetryFailed()` if the call fails,
which restores `Failed` and the block in one step.

## The receiver call

`_execute` has three details that matter:

1. **Gas floor.** The EVM forwards at most 63/64 of the remaining gas. If the relayer (or
   anyone calling `retry`) supplies too little, the receiver gets less than `executionGas`
   and may run out of gas through no fault of its own; the endpoint would then record a
   failure, and on an ordered channel block it. The check
   `gasleft() >= executionGas * 64 / 63 + GAS_RESERVE` guarantees the full allowance can be
   forwarded and enough remains to finish. Failing the check reverts, so nothing is
   recorded.
2. **Code check.** A call to an address without code succeeds. Treating that as a delivery
   would silently drop the message.
3. **No return-data copy.** The call is made in assembly with a zero-length output area. A
   high-level `try/catch` or `(bool ok, bytes memory ret) = call(...)` copies whatever the
   receiver returns or reverts with, and the memory expansion is paid by the endpoint
   after the gas limit no longer applies.

## Reentrancy

`deliver`, `retry` and `skip` share a lock. During `onMessage` the receiver could
otherwise call `retry` on the message being executed (when it is itself a retry, its
status would have to be handled very carefully), or `skip` the message that blocks its
ordered channel while a later one is half processed. With the lock those calls revert with
`Reentrancy()`. Independently of the lock, status is written before the external call, so
a message can never be executed twice.

## Pitfalls

- Reverting `deliver` when the receiver reverts.
- Putting `send` under the same lock as `deliver`.
- Refunding before the nonce and fee are recorded.
- Forwarding "all remaining gas", or a fixed amount without checking that it is available.
- Using a boolean per packet for replay but a counter that only advances on success for
  ordered channels (a failing message can then never be passed).
- Letting anyone `skip`: skipping drops a message, which only the receiving application may
  decide.
