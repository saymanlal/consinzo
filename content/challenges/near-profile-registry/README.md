# NEAR Profile Registry Keyed by Caller

## Objective
Implement `ProfileRegistry` in `src/ProfileRegistry.ts`. Every account owns at most one profile. Writes always apply to the profile of the account that calls the contract.

## Interface

```ts
export interface Profile {
  name: string;
  bio: string;
  updatedAt: bigint; // near.blockTimestamp() of the last setProfile
}

setProfile(name: string, bio: string): void
getProfile(account: string): Profile | null
deleteProfile(): void
profileCount(): number
```

## Rules
1. `setProfile(name, bio)` creates or replaces the profile of `near.predecessorAccountId()`.
   - `name.length` must be between 1 and 32, otherwise throw an error containing `Invalid name`.
   - `bio.length` must be at most 160 (an empty bio is allowed), otherwise throw an error containing `Bio too long`.
   - `updatedAt` is set to `near.blockTimestamp()`.
2. `getProfile(account)` returns the profile of any account, or `null` if it has none.
3. `deleteProfile()` removes the caller's profile. If the caller has no profile it throws an error containing `Profile not found`.
4. `profileCount()` is the number of accounts that currently have a profile. Updating an existing profile does not change it.
5. A rejected call must not change any state.

## What the tests check
Create, update and delete flows, isolation between accounts, the length boundaries, the count after updates and deletes, and re-creating a profile after deleting it.
