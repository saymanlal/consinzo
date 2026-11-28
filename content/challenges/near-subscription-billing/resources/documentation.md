# Recurring payments on NEAR

## No scheduled execution
A contract only runs when it is called. There is no on-chain timer, so recurring billing is driven by an external *keeper* transaction. The contract must compute, from timestamps alone, how many periods became due since it last ran and must behave the same whether the keeper calls every minute or once a month.

## Prepaid balances
A contract cannot pull NEAR out of a user's account. The subscriber therefore deposits funds in advance (`near.attachedDeposit()`), and each charge moves value inside the contract's own books from the subscriber's balance to the merchant's earnings.

## Lazy settlement
Because state only changes on calls, every method that depends on "what is owed right now" has to bring the account up to date first. This pattern is called lazy settlement. Any method that lets value leave the contract (a withdrawal) is the most important place to apply it.

## Period arithmetic
Keep the due date as a timestamp and advance it by whole periods. With `bigint` nanosecond timestamps there is no rounding; comparisons such as `now >= paidUntil` define precisely on which side of the boundary a call falls.

## Permissionless keepers
`charge` takes no trust in its caller: it can only do what the stored schedule already requires. That makes it safe to leave open to anyone.
