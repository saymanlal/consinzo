# Solution Explanation: Prepaid Subscription Billing

## One settle routine
All time-dependent state changes live in `settle(account)`. It loops while the subscription is `ACTIVE` and a period is due (`now >= paidUntil`):

1. a pending cancellation ends the subscription without charging;
2. an insufficient balance marks it `LAPSED` without charging and without touching the balance;
3. otherwise one price moves from the subscriber to the merchant and `paidUntil` advances by one period.

The loop ends because every iteration either changes the status or advances `paidUntil`.

`charge`, `subscribe`, `cancel` and `withdrawBalance` all call `settle` before doing anything else. This is what makes the contract safe against a subscriber who withdraws just before the keeper arrives: the withdrawal itself collects the due periods.

## Advancing the schedule
`paidUntil += periodNs` keeps the billing dates on a fixed grid. Using `now + periodNs` would hand the subscriber the delay between the due date and the keeper's transaction for free, and it would make the number of charged periods depend on how often the keeper runs.

## Cancellation
`cancel` only sets a flag. The subscriber already paid for the running period, so `isActive` stays true until `paidUntil`, and the next settle turns the status into `CANCELLED` instead of charging.

## Views
`isActive` does not settle (views cannot write). It reports `false` as soon as the paid period has ended, even if the balance would cover a renewal, because the renewal has not been collected yet.

## Pitfalls
- Checking the balance before the cancellation flag lapses a cancelled subscription, or worse, charges it once more.
- Letting `subscribe` overwrite an `ACTIVE` subscription discards due periods.
- Forgetting to reset `cancelRequested` on re-subscription cancels the new subscription at its first renewal.
