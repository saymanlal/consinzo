# Solution Explanation: Enumerable Role Registry

## Data layout
`LookupMap` has no iteration, so enumeration needs its own structure. The reference keeps

- `members[role]`: the ordered list of accounts, and
- `positions[(role, account)]`: the index of the account in that list.

`hasRole` is a single `containsKey` on `positions`. The composite key is length-prefixed (`"<len>:<role>:<account>"`), so no pair of different `(role, account)` values can produce the same key.

## Swap and pop
Removing from the middle of an array is O(n) and changes every later index. Instead the last member is copied into the vacated slot, its stored position is updated, and the array is popped. The special case is removing the last element itself: then nothing is moved and only the pop and the index deletion happen. Forgetting to update the moved member's position is the classic bug here; the hidden test removes the member that was just moved to catch it.

## Authorisation
`requireAdminOf(role)` resolves the admin role (default `ADMIN_ROLE`) and checks that the predecessor holds it. `setRoleAdmin` uses the same check against the *current* admin role, so administration can be delegated and handed back but never seized.

## Last admin rule
`remove` asserts that it is not about to delete the only `ADMIN_ROLE` member, before any write. Both `revokeRole` and `renounceRole` go through `remove`, so the rule cannot be bypassed by picking the other entry point.

## Pitfalls
- Returning `true` for a repeated grant and pushing a duplicate entry breaks the member count.
- Checking the caller's membership of `role` instead of `getRoleAdmin(role)` lets any member mint more members.
- Using `signerAccountId()` would let any contract the admin calls administer roles on the admin's behalf.
