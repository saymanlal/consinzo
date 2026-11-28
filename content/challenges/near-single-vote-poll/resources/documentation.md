# Background: one action per account

- "Once per account" rules are enforced by recording the account in contract storage the first time and checking for the record on later calls. The identity must be `near.predecessorAccountId()`.
- `LookupMap.get` returns `null` for a missing key. When the stored values can be falsy (`0`, `""`, `false`, `0n`), use `containsKey` or an explicit `=== null` comparison.
- Small, fixed-size data such as the tallies of a handful of options can live in a plain array in contract state. Unbounded data such as the set of voters belongs in a collection, because the whole contract state object is loaded on every call.
- JavaScript numbers accept fractions and `NaN`; `Number.isInteger` is the standard guard for values used as indices.
