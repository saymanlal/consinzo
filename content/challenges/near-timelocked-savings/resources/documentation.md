# Background: time in NEAR contracts

- `near.blockTimestamp()` returns the timestamp of the block that includes the call, in nanoseconds since the Unix epoch, as a `bigint`. One second is `1_000_000_000n` nanoseconds.
- Block time is the only notion of "now" a contract can rely on. All calls in the same block see the same value, and it never decreases from one block to the next.
- A timelock stores a deadline and compares it with the block timestamp on each call. Decide explicitly whether the deadline instant itself counts as locked or unlocked and test both sides of the boundary.
- Deposits arrive with the call and are read with `near.attachedDeposit()`. This exercise tracks the payout as a return value; a deployed contract would send the NEAR back with a transfer action.
