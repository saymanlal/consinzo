# NEAR Revocable Vesting Grants with Cliff

## Objective
Implement `VestingVault` in `src/VestingVault.ts`. A grantor locks NEAR (the attached deposit) for a beneficiary. Nothing is vested before the cliff; after it the grant vests linearly until `startNs + durationNs`. The grantor may revoke a revocable grant: what has vested stays with the beneficiary, the rest goes back to the grantor.

Payouts are modelled as an internal ledger: `release` and `revoke` credit `balanceOf(account)` instead of sending a transfer.

All times are nanoseconds (`near.blockTimestamp()`), all amounts are `bigint`.

## Interface

```ts
createGrant(beneficiary: string, startNs: bigint, cliffNs: bigint, durationNs: bigint, revocable: boolean): number
vestedAmount(id: number): bigint
releasable(id: number): bigint
release(id: number): bigint
revoke(id: number): bigint
getGrant(id: number): Grant | null
balanceOf(account: string): bigint
```

## Rules
1. `createGrant`
   - The caller (`near.predecessorAccountId()`) is the grantor and `near.attachedDeposit()` is the grant `total`.
   - Throws `"Invalid grant"` if the deposit is zero, `beneficiary` is empty or equal to the grantor, `durationNs` is zero, or `cliffNs > durationNs`.
   - Ids are sequential and start at `1`. `released` starts at `0n`, `revoked` at `false`.
2. `vestedAmount(id)` at the current block timestamp `now`:
   - `0n` while `now < startNs + cliffNs` (this includes any time before `startNs`);
   - `total` once `now >= startNs + durationNs`;
   - otherwise `total * (now - startNs) / durationNs`, rounded down.
   - For a revoked grant it returns the amount that was vested at the moment of revocation, forever.
3. `releasable(id)` is `vestedAmount(id) - released`.
4. `release(id)`: only the beneficiary (`"Not beneficiary"`). Throws `"Nothing to release"` when `releasable` is zero. Adds the releasable amount to `released`, credits the beneficiary's balance and returns the amount.
5. `revoke(id)`: only the grantor (`"Not grantor"`). Throws `"Not revocable"` for a non-revocable grant and `"Already revoked"` on a second call. It freezes the grant at the currently vested amount (the grant's `total` becomes that amount), credits the unvested remainder to the grantor's balance and returns the remainder (which may be `0n`). The beneficiary can still release what was vested but not yet released.
6. Every function that takes an id throws `"Grant not found"` for an unknown id.

## What the tests check
Cliff and end boundaries, rounding, that the sum of all releases never exceeds the grant, revocation before the cliff, mid-way and after full vesting, access control and input validation.
