# Reference Solution Explanation

- **Owner capture**: `owner = msg.sender` in the constructor. The variable is `immutable`, so reading it
  costs no storage access and it can never be overwritten by a later bug.
- **Check first**: `set` compares `msg.sender` with `owner` before any write. A revert undoes state
  changes anyway, but putting the check first keeps the function easy to audit and cheap to reject.
- **Custom error**: `NotOwner(msg.sender)` is cheaper than a revert string and gives callers the
  offending address in the revert data.
- **Event data**: the previous value is copied to a local before the overwrite so
  `ValueChanged(oldValue, newValue)` reports both sides of the change.

## Pitfalls

- Hard-coding an owner address or using `tx.origin` instead of `msg.sender`.
- Skipping the counter or the event when `newValue` equals the current value. The rules count every
  successful call.
- Counting the constructor as an update.
