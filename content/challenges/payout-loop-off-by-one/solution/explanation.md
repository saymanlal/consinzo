# Reference Solution Explanation

## Root cause

```solidity
for (uint256 i = 0; i < count - 1; i++) { ... }
```

The loop visits indexes `0 .. count - 2`. The author combined two correct idioms
(`i < count` and `i <= count - 1`) into an incorrect one. The effect is hidden by the
cleanup that follows: `delete payees` and `totalOwed = 0` erase the evidence that one
entry was never paid.

## Fix

Use the half-open bound `i < count`. The reference additionally copies the queue to
memory and clears storage before making any external call. A payee contract that calls
back while it is being paid then sees an empty queue, which keeps the function safe even
if the owner check is relaxed later.

## Pitfalls

- `i <= count` reads past the end of the array and reverts with a panic.
- `i <= count - 1` is correct for non-empty arrays but underflows for an empty one. Here
  the `NoPayees()` check runs first, yet `i < count` is still the form to prefer.
- Paying the last entry in a separate statement after the loop pays it twice when someone
  later corrects the loop bound.
- Do not skip a failed payment and continue. The specification requires the batch to be
  atomic, otherwise the cleared queue would again lose an unpaid entry.
