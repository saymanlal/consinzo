# Background: Liquidity-Network Bridges

## Fast path and slow path

A transfer through a liquidity network has two legs on the destination chain:

1. **Fulfilment.** A relayer sees the user's deposit on the source chain and pays the user
   on the destination chain out of pooled LP capital, minus a fee.
2. **Settlement.** Later, the canonical bridge delivers the user's original funds. They go
   to the pool, which is now whole again and richer by the fee.

If nobody fronts the transfer, settlement simply pays the user: slow, but with no fee.
The two legs can arrive in either order and the contract must handle each transfer exactly
once per leg.

## Pool shares

LPs own shares of the pool rather than fixed token amounts. With `A` total assets and `S`
total shares:

- depositing `a` mints `a * S / A` shares;
- burning `s` shares returns `s * A / S` tokens.

When fees are added to `A` without minting shares, every share is worth more. Integer
division must round against the party making the trade.

## What counts as an asset

Tokens paid out and awaiting reimbursement are still the LPs' property: a receivable. A
pool that values itself only by cash on hand shows a loss every time it fronts a transfer
and lets a depositor buy shares cheaply during that window. Valuing the receivable at cost
keeps the price flat during the gap; the fee is added when it is actually received.

## Internal accounting versus balances

`balanceOf(address(this))` can be changed by anyone with a plain transfer. Vault-style
contracts that derive prices from it are exposed to share-price manipulation, especially
when the pool is nearly empty. Keeping explicit counters avoids the problem and makes it
possible to hold funds that are not LP property (such as protocol fees) in the same
contract.
