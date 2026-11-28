# Solution Explanation: NEAR Time-Locked Savings Box

1. **One record per account.** A box is `{ amount, unlockAt }` stored under the caller's account id. Its existence, not a zero amount, decides which deposit rule applies.
2. **Two deposit paths.** A new box requires `unlockAt > now`, so a box cannot be created already unlocked. A top-up requires `unlockAt >= existing.unlockAt`. Without that rule a saver, or more importantly any future logic that deposits on a user's behalf, could reset the lock to an earlier time and defeat the purpose of the contract.
3. **Boundary.** The box is unlocked when `now >= unlockAt`. Using `>` would make the documented unlock instant unusable; using a caller-supplied "now" would make the lock meaningless.
4. **Withdraw clears the box.** The record is removed and the global total reduced before the amount is returned. A second `withdraw` finds no box. Removing the record (rather than leaving a zero-amount box with the old unlock time) is what lets the next deposit start fresh.
5. **Total.** `totalLocked` is updated by exactly the deposited or withdrawn amount on each path, so it always equals the sum of the boxes.

## Pitfalls
- Overwriting the amount instead of adding on a top-up.
- Applying the "must be in the future" rule to top-ups, which would forbid adding to an already unlocked box at its current unlock time.
- Leaving the old unlock time behind after a withdrawal.
