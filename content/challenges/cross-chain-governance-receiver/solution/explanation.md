# Reference Solution Explanation

## Approach

The receiver is a timelock whose proposer is a contract on another chain. Three ideas carry
the design.

**1. Authenticate the origin in two layers.** `msg.sender == messenger` proves that the
call came through the bridge. The `(sourceChainId, sourceSender)` pair, as reported by the
bridge, proves who sent it. Both the chain id and the sender are compared: an attacker can
often deploy to, or control, the same address on a different chain.

**2. Commit to the actions, verify at execution.** Only
`keccak256(abi.encode(targets, values, calldatas))` is stored. `execute` recomputes the
hash from calldata. `abi.encode` (not `encodePacked`) is used so that array boundaries are
part of the encoding and two different action lists cannot collide. The id is burned
permanently: `ProposalExists()` triggers on any non-`None` status, so redelivering a
message cannot extend an eta, replace a hash or revive a cancelled proposal.

**3. Checks, effects, interactions.** `execute` validates status, window and hash, sets
`Executed`, and only then calls out. A target that re-enters `execute` for the same
proposal hits `NotQueued()`. If any action fails, `revert CallFailed(i)` unwinds the status
write and all earlier actions, so the proposal remains queued and can be retried inside
the grace period (for example after the receiver has been funded).

`Expired` is derived in `state()` from the stored `Queued` status and the clock; it is never
written. That is why `cancel` works on an expired proposal and `execute` reports
`ProposalExpired()` rather than `NotQueued()` for it.

The setters are guarded by `msg.sender == address(this)`. The only way the receiver calls
itself is through an executed proposal, so every configuration change inherits origin
authentication and the delay. `eta` is fixed when a proposal is queued; a later `setDelay`
affects new proposals only.

## Pitfalls

- Checking only `sourceSender` and ignoring `sourceChainId`.
- Marking the proposal executed after the loop (re-entrancy runs the actions twice).
- Catching a failed action and continuing, which leaves a half-executed proposal.
- Allowing a proposal id to be queued again after cancel or execute.
- Recomputing `eta` from the current `delay` at execution time.
- Using `<` instead of `<=` at the end of the grace period.
