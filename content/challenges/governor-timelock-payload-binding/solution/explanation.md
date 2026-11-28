# Why the patch works

Governance has three steps that must all refer to the same thing: what was voted on, what was
queued, and what is executed. The starter links vote and queue through the proposal id, but
execution takes the call from its caller. The id proves that *some* proposal passed, not
*which call* passed.

The reference introduces a commitment and checks it at both trust boundaries.

1. `propose` stores `payloadHash = keccak256(abi.encode(target, value, data))`. From this
   point the payload cannot change without changing the hash.
2. `PayloadGovernor.execute` recomputes the hash from its arguments and reverts with
   `PayloadMismatch()` if it differs.
3. `PayloadGovernor.queue` hands the hash to the timelock, which stores it next to the eta.
   `PayloadTimelock.execute` recomputes the hash again before releasing funds.

The second check is deliberate redundancy. The timelock owns the treasury, so it should not
depend on every present and future governor implementation remembering to validate. The
test that pranks the governor address exercises exactly that.

## Pitfalls

- Restricting `execute` to voters does not fix the bug; a single voter could still replace
  the payload the majority approved.
- Hash with `abi.encode`, and include all three fields. `abi.encodePacked(target, value, data)`
  is unambiguous here only by accident and omitting `value` leaves the ETH amount free.
- Clear the timelock entry before the external call and keep it if the call reverts. The
  reference deletes first and relies on the revert to restore it.
- Storing the full payload on-chain also works but costs far more gas than one hash.
