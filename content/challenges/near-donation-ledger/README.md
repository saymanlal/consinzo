# NEAR Donation Ledger with Top Donor

## Objective
Implement `DonationLedger` in `src/DonationLedger.ts`. Accounts donate by attaching a deposit. The contract keeps a running total per donor and overall, and always knows who the top donor is.

## Interface

```ts
donate(): bigint
donationOf(account: string): bigint
totalDonated(): bigint
donorCount(): number
topDonor(): string
topDonation(): bigint
```

## Rules
1. `donate()` reads the amount from `near.attachedDeposit()` and the donor from `near.predecessorAccountId()`.
   - The deposit must be greater than `0n`, otherwise throw an error containing `Deposit required`.
   - It adds the deposit to the donor's total and to the global total, and returns the donor's new total.
2. `donationOf(account)` returns the cumulative amount donated by `account` (`0n` if it never donated).
3. `totalDonated()` returns the sum of all donations.
4. `donorCount()` returns the number of distinct accounts that donated at least once.
5. `topDonor()` returns the account with the largest cumulative total, and `topDonation()` returns that total. Before any donation they return `""` and `0n`.
6. Ties: the current top donor is replaced only when another account's cumulative total becomes **strictly greater**. An account that merely equals the top total does not take the lead.

## What the tests check
Accumulation across several donations, unique donor counting, zero-deposit rejection, leader changes driven by cumulative totals rather than single donations, and the tie rule.
