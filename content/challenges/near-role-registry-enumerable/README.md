# NEAR Role-Based Access Registry with Role Admins

## Objective
Implement `RoleRegistry` in `src/RoleRegistry.ts`: a registry other contracts can consult to answer "does account X hold role R?". Roles are plain strings. Every role has an *admin role*; only holders of the admin role may grant or revoke the role. Members of a role can be enumerated.

The caller is always `near.predecessorAccountId()`.

## Interface

```ts
export const ADMIN_ROLE = "admin";

constructor()                                    // the deployer becomes the first member of ADMIN_ROLE
grantRole(role: string, account: string): boolean
revokeRole(role: string, account: string): boolean
renounceRole(role: string): void
setRoleAdmin(role: string, adminRole: string): void
hasRole(role: string, account: string): boolean
getRoleAdmin(role: string): string
getRoleMemberCount(role: string): number
getRoleMember(role: string, index: number): string
getRoleMembers(role: string, fromIndex: number, limit: number): string[]
```

## Rules
1. The admin role of every role is `ADMIN_ROLE` until changed with `setRoleAdmin`. This includes `ADMIN_ROLE` itself.
2. `grantRole` and `revokeRole` require the caller to hold `getRoleAdmin(role)`; otherwise they throw `"Missing role"`.
   - `grantRole` returns `true` when the account was added and `false` when it already held the role (no change, no duplicate entry).
   - `revokeRole` returns `true` when the account was removed and `false` when it did not hold the role.
3. `renounceRole(role)` removes the role from the caller. Throws `"Role not held"` if the caller does not hold it.
4. `setRoleAdmin(role, adminRole)` requires the caller to hold the *current* admin role of `role` (`"Missing role"`).
5. The registry must never be left without a root admin: `revokeRole` and `renounceRole` throw `"Last admin"` if they would remove the only remaining member of `ADMIN_ROLE`.
6. Empty role names throw `"Invalid role"`; empty account ids throw `"Invalid account"`.
7. Enumeration
   - New members are appended, so `getRoleMember(role, i)` returns members in grant order.
   - Removal uses swap-and-pop: the last member moves into the removed member's slot and the list shrinks by one.
   - `getRoleMember` throws `"Index out of bounds"` for an invalid index.
   - `getRoleMembers(role, fromIndex, limit)` returns at most `limit` members starting at `fromIndex`; it returns an empty array when `fromIndex` is past the end.

## What the tests check
Granting, revoking and renouncing, idempotent grants, delegated role admins, the last-admin rule, the exact enumeration order after removals and pagination bounds.
