# Reference Solution Explanation

## Structure

The whole mechanism rests on one stored timestamp. `lastHeartbeat` is written by every successful
owner-only call, and the heir's right to claim is the pure comparison
`block.timestamp >= lastHeartbeat + silencePeriod`.

`claim()` does three things, and all three matter:

1. `owner = msg.sender` removes every right of the previous owner, because all owner functions
   compare against the stored `owner`.
2. `heir = address(0)` means the inherited wallet has no pending claimant. Without it the old heir
   address would stay in the slot, which is harmless only because it now equals the owner; clearing
   it keeps the state honest and lets the new owner choose a successor.
3. `lastHeartbeat = block.timestamp` restarts the timer for the new owner.

## Pitfalls

- **Boundary.** The heir may claim at exactly `lastHeartbeat + silencePeriod`; one second earlier
  reverts.
- **A late heartbeat is still a heartbeat.** If the period has elapsed but the heir has not yet
  claimed, the owner can still call `heartbeat()` and the heir must wait a full period again. The
  switch reacts to the heir's `claim`, not to the passage of time alone.
- **Deposits are not heartbeats.** `receive()` must not touch `lastHeartbeat`, otherwise anyone
  could keep the owner "alive" forever by sending 1 wei.
- **Heir equal to owner.** `setHeir(owner)` is rejected, since it would silently disable the switch.
- **`withdraw` shortfall.** The reference does not compare `amount` with the balance explicitly:
  a `call` with more value than the contract holds fails and is reported as `TransferFailed()`.
