# Reference Solution Explanation

## The gate

`_requireNotPaused()` reverts with `EnforcedPause()` when the flag is set. It is the first
statement of `transfer`, `transferFrom` and `burn`, so a paused call fails before allowance or
balance checks run and cannot modify any state.

## What stays open and why

- `approve` moves no tokens. Leaving it open lets holders revoke approvals to a compromised
  spender while the token is paused, which is often the reason for the pause.
- `mint` is owner-only and stays open so the owner can carry out a recovery (for example
  re-issuing balances) before resuming. The minted tokens are still immobile until `unpause`.
- `burn` is blocked: during an incident the owner wants balances frozen exactly as they are so
  that a snapshot taken for remediation remains valid.

These are policy choices. What matters is that each function's behaviour is deliberate and
written down; "pause everything" and "pause only transfer" are both common sources of bugs when
the choice is accidental.

## State machine

`pause` requires `!paused` and `unpause` requires `paused`. The owner check runs first in both,
so a non-owner learns nothing about the state from the error.

## Pitfalls

- Gating `transfer` but forgetting `transferFrom` leaves an open path for any existing approval.
- Putting the pause check after the allowance decrement is harmless only because the revert
  rolls back; it still reports the wrong error.
- Gating `approve` prevents users from revoking approvals in an emergency.
