# NEAR Prepaid Subscription Billing

## Objective
Implement `SubscriptionBilling` in `src/SubscriptionBilling.ts`. A merchant (the deployer) defines plans. Subscribers deposit NEAR into a prepaid balance and subscribe to a plan. Contracts cannot wake themselves up, so a keeper (anyone) calls `charge(account)` to collect the price of every period that has become due.

Transfers are modelled as internal ledgers: `balanceOf` for subscribers and `earnings` for the merchant. Times are nanoseconds.

## Types

```ts
type SubStatus = "ACTIVE" | "CANCELLED" | "LAPSED";
interface Plan { price: bigint; periodNs: bigint }
interface Subscription { planId: number; paidUntil: bigint; cancelRequested: boolean; status: SubStatus }
```

## Interface

```ts
constructor()                                    // owner = near.predecessorAccountId()
createPlan(price: bigint, periodNs: bigint): number
fund(): void
subscribe(planId: number): void
charge(account: string): number
cancel(): void
withdrawBalance(amount: bigint): bigint
collectEarnings(): bigint
isActive(account: string): boolean
getSubscription(account: string): Subscription | null
getPlan(planId: number): Plan | null
balanceOf(account: string): bigint
earnings(): bigint
```

## Rules
1. `createPlan`: owner only (`"Not owner"`). `"Invalid plan"` unless `price > 0n` and `periodNs > 0n`. Ids start at `1`.
2. `fund()`: adds `near.attachedDeposit()` to the caller's prepaid balance. `"Zero deposit"` if nothing is attached.
3. **Settling.** Settling an account means repeating the following while its subscription is `ACTIVE` and `now >= paidUntil`:
   - if `cancelRequested` is set, the status becomes `CANCELLED` and settling stops;
   - else if the balance is lower than the plan price, the status becomes `LAPSED` and settling stops (the balance is left untouched);
   - else the price moves from the balance to the merchant's earnings and `paidUntil` increases by exactly `periodNs`.
4. `charge(account)`: callable by anyone. `"No subscription"` if the account never subscribed. Settles the account and returns the number of periods charged by this call.
5. `subscribe(planId)`: `"Plan not found"` for an unknown plan. Settles the caller first. `"Already subscribed"` if the status is still `ACTIVE`. `"Insufficient balance"` if the balance is below the price. Otherwise charges the first period immediately and stores `{ planId, paidUntil: now + periodNs, cancelRequested: false, status: "ACTIVE" }`. A `CANCELLED` or `LAPSED` subscriber may subscribe again.
6. `cancel()`: settles the caller, then throws `"No active subscription"` unless the status is `ACTIVE`. Sets `cancelRequested`. The subscription stays active until `paidUntil`; nothing is refunded for the running period and no further period is charged.
7. `withdrawBalance(amount)`: settles the caller first, then throws `"Insufficient balance"` unless `0n < amount <= balance`. Reduces the balance and returns `amount`. Periods that are already due can therefore not be dodged by withdrawing.
8. `collectEarnings()`: owner only (`"Not owner"`). Returns the accumulated earnings and resets them to zero.
9. `isActive(account)` is a view: `true` only when the status is `ACTIVE` and `now < paidUntil`. It does not settle.

## What the tests check
Immediate first charge, catch-up over several periods, the exact `paidUntil` after charging, lapse on insufficient funds, cancellation at period end, settlement before withdrawal, re-subscription and access control.
