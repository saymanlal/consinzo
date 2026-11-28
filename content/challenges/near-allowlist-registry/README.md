# NEAR Owner-Managed Allowlist with Guarded Action

## Objective
Implement `Allowlist` in `src/Allowlist.ts`. The owner maintains a set of allowed accounts. Allowed accounts can call `checkIn()`; everyone else is rejected.

## Interface

```ts
constructor()                     // owner = near.predecessorAccountId()
add(account: string): void
remove(account: string): void
isAllowed(account: string): boolean
allowedCount(): number
checkIn(): number
checkInsOf(account: string): number
getOwner(): string
```

## Rules
1. The account that constructs the contract is the owner. The owner is **not** on the allowlist automatically.
2. `add(account)`:
   - Caller must be the owner, otherwise throw an error containing `Only owner`.
   - `account` must be non-empty, otherwise throw an error containing `Invalid account`.
   - If the account is already on the list, throw an error containing `Already listed`.
3. `remove(account)`:
   - Caller must be the owner (`Only owner`).
   - If the account is not on the list, throw an error containing `Not listed`.
4. `isAllowed(account)` reports current membership. `allowedCount()` is the number of accounts currently on the list.
5. `checkIn()` is the guarded action. The caller must currently be on the allowlist, otherwise throw an error containing `Not allowlisted`. It increases the caller's check-in count by one and returns the new count.
6. `checkInsOf(account)` returns the number of successful check-ins of an account. Removing an account from the list does not reset this number, and an account that is added again continues from its previous count.
7. The owner check is performed before the argument checks.

## What the tests check
Owner-only management, the guard on `checkIn`, the count after adds and removes, duplicate and missing entries, and that removal blocks further check-ins without erasing history.
