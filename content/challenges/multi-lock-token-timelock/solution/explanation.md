# Reference Solution Explanation

## Data model

`mapping(address => Lock[])` gives every user an append-only list. The id of a lock is its
index, so ids are small, predictable and never reused. A withdrawn lock stays in the array with
`withdrawn = true`; deleting or swapping elements would change the meaning of existing ids.

A private helper `_liveLock(user, id)` performs the two checks shared by `extendLock` and
`withdraw` (`InvalidLock`, then `AlreadyWithdrawn`) and returns a storage pointer.

## Functions

- `lock` validates, pushes the struct, updates `totalLocked` and then pulls the tokens.
- `extendLock` requires the new time to be later than the current unlock time and later than
  now. The second condition matters for matured locks: without it a user could "extend" to a
  time that is already in the past, which is a no-op that emits a misleading event.
- `withdraw` sets the flag and reduces `totalLocked` before transferring.
- `withdrawMatured` makes one pass, flags each eligible lock, and performs a single transfer
  for the sum. It reverts if nothing was eligible so that callers are not misled by a
  successful no-op.

## Pitfalls

- Using `>` instead of `>=` for maturity (or `<=` instead of `<` in `StillLocked`) shifts the
  boundary by one second.
- Forgetting the `withdrawn` flag in `withdrawMatured` or in the views lets a lock be counted or
  paid twice. Since all users' tokens sit in one balance, a double withdrawal would be paid
  with other users' funds.
- Indexing `locks[user][lockId]` without a bounds check reverts with a panic instead of the
  specified `InvalidLock()`.
- The batch functions are linear in the number of locks of the caller. Only the user can add
  to their own list, so a third party cannot make it expensive.
