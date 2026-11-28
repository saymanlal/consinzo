# Solution Explanation: NEAR Owner-Managed Allowlist

1. **Two separate permissions.** Management (`add`, `remove`) is restricted to the stored owner. The guarded action (`checkIn`) is restricted to accounts present in the allowlist map. The two sets are independent: the owner must add itself to check in, and a member cannot manage the list.
2. **Set semantics on a LookupMap.** Membership is "the key exists". `add` requires the key to be absent and `remove` requires it to be present, so the count moves by exactly one on every successful call and can never drift.
3. **Remove the key.** Storing `false` instead of removing would work only if every reader tested the value. Deleting the key keeps a single test (`containsKey`) and also frees storage.
4. **History survives removal.** Check-in counts live in a separate map that `remove` does not touch.

## Pitfalls
- Treating the owner as allowlisted.
- Checking arguments before the owner check, which gives different errors to unauthorised callers.
- Clearing or resetting the check-in count on removal.
