# NEAR Status Message with Length Limit and Update Counter

## Objective
Implement `StatusBoard` in `src/StatusBoard.ts`. Each account publishes one short status message. The contract enforces a maximum length chosen at construction and counts successful updates per account.

## Interface

```ts
constructor(maxLength: number = 64)
setStatus(message: string): number
getStatus(account: string): string | null
clearStatus(): void
updateCount(account: string): number
totalUpdates(): number
getMaxLength(): number
```

## Rules
1. The constructor requires `maxLength` to be an integer `>= 1`, otherwise it throws an error containing `Invalid max length`.
2. `setStatus(message)` sets the status of `near.predecessorAccountId()`.
   - An empty message throws an error containing `Empty status`.
   - A message longer than `maxLength` throws an error containing `Status too long`. A message of exactly `maxLength` characters is accepted.
   - On success the caller's update counter and the global counter each increase by one, and the caller's new counter value is returned. Setting the same text again still counts as an update.
3. `getStatus(account)` returns the current status or `null`.
4. `clearStatus()` removes the caller's status. If the caller has no status it throws an error containing `No status`. Clearing is not an update: it changes neither counter.
5. `updateCount(account)` returns the number of successful `setStatus` calls by that account, including those made before a clear. `totalUpdates()` is the sum over all accounts.
6. A rejected call must not change any state.

## What the tests check
Per-account statuses and counters, the exact length boundary for several limits, counters surviving a clear, rejected calls leaving state untouched, and constructor validation.
