# Solution Explanation: NEAR Owner-Only Configuration

1. **Owner captured at construction.** The constructor stores `near.predecessorAccountId()`. Every mutating method compares the current predecessor with it before doing anything else, so an unauthorised caller learns nothing about argument validity and cannot change state.
2. **`null` versus empty string.** `LookupMap.get` returns `null` only for a missing key. Comparing `oldValue !== value` therefore treats `""` as a real value: setting `""` on a missing key is a change, setting it again is not.
3. **Log only effective changes.** The no-op check runs before the write. Each successful call appends exactly one entry containing the previous value, which makes the log a complete history that can be replayed.
4. **Ownership transfer.** Replacing the stored owner is enough: all checks read the field, so the previous owner loses access immediately.

## Pitfalls
- Using `near.signerAccountId()` for the owner check; a contract called by the owner could then act with the owner's rights.
- Writing `oldValue ?? ""` into the log, which hides the difference between a new key and an emptied one.
- Appending a log entry before the validation has passed.
