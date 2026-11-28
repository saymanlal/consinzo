# NEAR Owner-Only Configuration with Change Log

## Objective
Implement `OwnerConfig` in `src/OwnerConfig.ts`: a string key-value configuration that only the contract owner may change, plus an append-only log of every change.

## Interface

```ts
export interface ConfigChange {
  key: string;
  oldValue: string | null; // null when the key had no value before
  newValue: string;
  changedBy: string;       // the owner account that made the change
  timestamp: bigint;       // near.blockTimestamp()
}

constructor()                                 // owner = near.predecessorAccountId()
setValue(key: string, value: string): number  // returns the index of the log entry
getValue(key: string): string | null
changeCount(): number
getChange(index: number): ConfigChange | null
transferOwnership(newOwner: string): void
getOwner(): string
```

## Rules
1. The account that constructs the contract becomes the owner.
2. `setValue(key, value)`:
   - The caller must be the owner, otherwise throw an error containing `Only owner`.
   - `key` must be non-empty, otherwise throw an error containing `Invalid key`.
   - If the key already holds exactly `value`, throw an error containing `No change`.
   - Otherwise store the value, append a `ConfigChange` to the log and return the index of that entry (0 for the first change).
   - An empty string is a valid value and is different from "no value" (`null`).
3. `getValue(key)` returns the current value or `null`.
4. `changeCount()` returns the number of log entries; `getChange(index)` returns an entry or `null`.
5. `transferOwnership(newOwner)`: only the owner may call it (`Only owner`); `newOwner` must be non-empty (`Invalid owner`). Afterwards the previous owner has no rights. Ownership transfers are not written to the change log.
6. The owner check is performed before any other check.

## What the tests check
Owner-only writes, log contents and ordering, rejected no-op writes, the difference between an empty value and a missing one, and that rights move with ownership.
