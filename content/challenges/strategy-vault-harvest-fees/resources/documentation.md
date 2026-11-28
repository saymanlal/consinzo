# Strategy Vault Notes

## Vaults and strategies

A yield vault pools deposits and hands part of them to a strategy contract that earns a
return elsewhere. Shares represent a pro-rata claim on the pool. The ERC-4626 standard
describes the share/asset conversion; this exercise uses the same conversion rules but
focuses on what the standard leaves open: how deployed assets are valued and how fees and
losses are booked.

## Reported value

The vault cannot know continuously what a strategy position is worth. It records a debt
figure and updates it when the strategy reports. Between reports the share price is stable.
A report that is higher than the debt is profit, a lower one is a loss.

## Performance fees paid in shares

Minting shares to the fee recipient transfers value without moving assets. The number of
shares is chosen so that their value after the mint equals the fee. Existing holders are
diluted by exactly the fee.

## High-water marks

A performance fee should be charged on net new profit. Tracking the amount of loss that has
not yet been earned back, and offsetting profit against it first, has that effect.

## Liquidity and losses on exit

When a withdrawal exceeds the idle balance the vault must unwind part of the strategy.
Unwinding can cost money. Vaults let the withdrawer state the largest loss it accepts in
basis points and revert beyond that, so a user is never forced to exit at an unknown price
and the cost of exiting is not passed on to those who stay.
