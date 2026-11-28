# Reference Solution Explanation

## Approach

The contract is a small state machine per request id: `None → Pending → Fulfilled` or
`None → Pending → Cancelled`. Every entry point first checks that the request is in the
state it needs, so the terminal states are final.

- **Request.** Arguments are validated, then the per-player pending flag is checked and
  set, then the coordinator is called. The request id is whatever the coordinator returns;
  the contract does not generate ids itself. Because ids come from outside, an id whose
  status is not `None` is refused with `DuplicateRequestId()` instead of overwriting the
  earlier request. The revert also undoes the pending flag set a few lines earlier.
- **Fulfilment.** `msg.sender` must be the coordinator. This is the whole security of the
  integration: if anyone could call the callback, anyone could choose the dice. The status
  check makes fulfilment happen at most once and rejects unknown and cancelled ids. The
  word-count check compares against the stored `diceCount`, not against a constant.
  Each word is reduced with `% sides` and shifted by one so faces run from 1 to `sides`.
- **Cancellation.** Only the requesting player, only while `Pending`, only once
  `REQUEST_TIMEOUT` has passed. It clears the pending flag so the player is not locked out
  by a coordinator that never answers. A late callback for the cancelled id fails the
  status check and cannot clear the pending flag of the player's *new* request.

## Pitfalls

- Omitting the coordinator check on the callback.
- Clearing `hasPendingRoll` in the callback without checking the request status: a late
  answer to a cancelled request would then unlock a second concurrent roll.
- `randomWords[i] % sides` without `+ 1` (faces 0 … sides-1).
- Assuming request ids are sequential and start at 1.
- Modulo bias: `2**256` is not a multiple of most side counts, but the bias is below
  `sides / 2**256` and is ignored here.
