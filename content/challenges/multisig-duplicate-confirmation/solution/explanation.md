# Why the patch works

The threshold is a property of a *set* of owners. The starter approximates the size of that
set with a counter that is incremented on every `confirm` call, so the counter measures calls,
not owners. One compromised or malicious key calls `confirm` twice and executes a 2-of-3
transaction alone.

The reference ties the counter to the per-owner flag:

```solidity
if (confirmed[txId][msg.sender]) revert AlreadyConfirmed();
confirmed[txId][msg.sender] = true;
t.confirmations += 1;
```

`revoke` already requires the flag to be set before it decrements. With both directions
guarded, `confirmations` always equals the number of owners whose flag is `true`.

The constructor gets the same treatment. `isOwner` doubles as the "seen" set, so a repeated
address reverts with `DuplicateOwner()`. The threshold is checked against the length of a
list that is now known to contain distinct, non-zero addresses.

## Pitfalls

- Making `confirm` silently ignore a repeat fixes the count but hides mistakes from callers
  and breaks the specified `AlreadyConfirmed()` revert.
- Fixing `confirm` but not the constructor leaves the same flaw at deployment time: with
  owners `[A, A]` and threshold 2, `A` is still alone.
- Checking the threshold before the duplicate scan must use the raw list length, which is
  only meaningful once duplicates are rejected. Do both.
- If owners could be removed, a stored counter would go stale; a wallet with owner management
  should recount live owners at execution time.
