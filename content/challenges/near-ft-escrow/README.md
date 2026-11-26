# NEAR Timelocked Escrow & Deposit Vault

## Objective
Implement `TimelockEscrow` in `src/Escrow.ts` using `LookupMap`, `near.predecessorAccountId()`, `near.attachedDeposit()`, and `near.blockTimestamp()`.

## Specification
1. `createEscrow(id: string, beneficiary: string, releaseAfterNs: bigint): void`:
   - Require non-empty `id`, non-empty `beneficiary`, `beneficiary !== caller`, `attachedDeposit > 0n`, and `!escrows.containsKey(id)`.
   - Store `{ depositor: caller, beneficiary, amount: deposit, releaseAfterNs, status: "OPEN" }`.
2. `release(id: string): bigint`:
   - Require existing `OPEN` escrow.
   - Caller must be `depositor` (any time) OR `beneficiary` when `near.blockTimestamp() >= releaseAfterNs`.
   - Transition `status` to `"RELEASED"`, credit `beneficiary` in `releasedBalances`, return `amount`.
3. `refund(id: string): bigint`:
   - Require existing `OPEN` escrow.
   - Caller must be `depositor` and `near.blockTimestamp() < releaseAfterNs` (before maturity) OR `beneficiary` voluntarily waiving claim at any time.
   - Transition `status` to `"REFUNDED"`, credit `depositor` in `refundedBalances`, return `amount`.
4. View methods: `getEscrow(id)`, `getReleasedBalance(account)`, `getRefundedBalance(account)`.
