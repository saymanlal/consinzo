# Reference Solution Explanation

- **Storage**: `mapping(address => bool) isAllowed` answers membership in one storage read, and
  `allowedCount` is maintained alongside it because a mapping cannot be counted.
- **Idempotent internals**: `_add` and `_remove` look at the current flag first and report whether
  they changed anything. The counter and the events move only on a real change, so repeated calls
  and duplicates inside a batch cannot make `allowedCount` drift.
- **Batch functions**: they loop over a `calldata` array and call the same internals, summing the
  `true` results. A zero address makes `_add` revert, and a revert discards every write made
  earlier in the same call, so the batch is atomic without extra code.
- **Two guards**: `onlyOwner` protects list management, `onlyAllowed` protects the action. They are
  independent: the owner is not on the list unless added, and a listed address cannot manage the
  list.

## Pitfalls

- Incrementing `allowedCount` on every `add`, or decrementing on every `remove`; the latter can
  underflow and revert.
- Skipping zero addresses silently in `addBatch` instead of reverting.
- Deleting `checkIns` on removal, which the rules do not ask for.
- Treating the owner as implicitly allowed.
