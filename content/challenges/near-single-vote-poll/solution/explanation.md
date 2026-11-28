# Solution Explanation: NEAR One-Account-One-Vote Poll

1. **Constructor validation.** A `Set` detects duplicate labels in one pass. The labels are copied with the spread operator so the poll's options are fixed at construction.
2. **One vote per account.** The chosen option is stored under the voter's account id. `containsKey` is the "has voted" test. A truthiness test on the stored value (`if (choices.get(caller))`) would treat a vote for option 0 as "not voted" and allow a second vote.
3. **Index validation.** `Number.isInteger` rejects fractions and `NaN`; the range check rejects negatives and indices past the end. The same helper guards `vote`, `tally` and `optionLabel`.
4. **Check before write.** Validation and the double-vote check both happen before any counter changes, so a rejected call leaves the tallies untouched and does not consume the caller's vote.
5. **Deterministic leader.** `leading()` scans the fixed, small tally array with a strict comparison, which returns the lowest index among tied options.

## Pitfalls
- Using `get(caller) !== null` is fine; using `!get(caller)` is not, because `0` is falsy.
- Letting a vote be changed, which would require decrementing the old tally.
- Returning `0` from `leading()` when no votes exist.
