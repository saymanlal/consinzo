# Recurring Payments On-Chain: Background

## Why subscriptions are awkward on a blockchain

A card subscription works because the merchant can pull money from the customer's account on a
schedule. An Ethereum account only moves ETH when its owner signs a transaction, and contracts
cannot schedule themselves. Every on-chain subscription design therefore needs two things:

1. funds the contract is allowed to move without a new signature, and
2. someone who sends the transaction that triggers each payment.

This challenge uses the simplest answers: the subscriber deposits ETH in advance, and the merchant
triggers each charge.

## Limiting what the merchant can take

Because the merchant triggers payments, the contract must bound them. The bound here is one
`price` per `period`, enforced with a per-subscriber timestamp that only moves forward in steps of
one period.

## Paid in advance versus in arrears

Billing in advance means a period is paid before it starts. Cancelling is then simple: the paid
period is not refunded, later periods are never charged, and no settlement is needed. Billing in
arrears needs a final pro-rata settlement at cancellation and exposes the merchant to unpaid usage.

## Pull payments

Both parties collect their money with their own transaction (`withdraw`, `collect`). The contract
never sends ETH as a side effect of another user's action, so a recipient that cannot receive ETH
only affects itself.
