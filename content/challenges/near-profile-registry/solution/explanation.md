# Solution Explanation: NEAR Profile Registry

1. **Ownership by key.** The profile map is keyed by `near.predecessorAccountId()`. Because writes never take an account argument, there is no code path through which one account can modify or delete another account's profile.
2. **Validation first.** Both length checks run before any write, so a failed update leaves the previous profile, its timestamp and the count unchanged.
3. **Accurate count.** `LookupMap` cannot report its size, so the contract tracks it. `containsKey` distinguishes a creation (count + 1) from an update (count unchanged). `deleteProfile` requires the key to exist before removing it, so the count can never go negative.

## Pitfalls
- Incrementing the count on every `setProfile`.
- Silently ignoring a delete of a missing profile, or decrementing the count for it.
- Treating an empty bio as invalid; only the name has a minimum length.
