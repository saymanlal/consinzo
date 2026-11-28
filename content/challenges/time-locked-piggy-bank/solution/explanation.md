# Reference Solution Explanation

- **Immutable configuration**: `owner` and `unlockTime` are set once in the constructor. Nobody,
  including the owner, can shorten the lock afterwards, which is the point of the contract.
- **Constructor validation**: `unlockTime_ <= block.timestamp` is rejected. A lock that is already
  open is almost certainly a mistake such as passing a duration instead of a timestamp.
- **Inclusive unlock**: the lock check is `block.timestamp < unlockTime`, so the first block whose
  timestamp equals `unlockTime` already allows a withdrawal, matching `isUnlocked()`.
- **Check order**: caller, then lock, then balance. A stranger learns nothing but "not owner", and
  the owner of an empty, locked bank is told about the lock first.
- **Safe remaining time**: `secondsUntilUnlock` returns early with `0` after the unlock time.
  Without the guard the subtraction would underflow and the view would revert forever.
- **Withdrawal**: the full balance is sent with `call` and the result is checked. No state is
  updated after the transfer, so re-entering `withdraw` only finds an empty balance.

## Pitfalls

- Using `>` instead of `>=` for the unlock comparison.
- Treating the constructor argument as a duration.
- Restricting deposits to the owner or to the locked period.
- Subtracting timestamps without checking which is larger.
- Relying on `block.timestamp` for second-level precision. Validators can shift it slightly, which
  is acceptable for a lock measured in days.
