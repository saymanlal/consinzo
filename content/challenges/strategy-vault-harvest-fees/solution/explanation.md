# Reference Solution Explanation

## Internal accounting

`totalAssets()` is `idleAssets + strategyDebt`. Neither value is read from a token balance.
This has two consequences. A direct token transfer to the vault cannot inflate the share
price, which removes the classic first-depositor donation attack. And profit inside the
strategy becomes visible only at `harvest`, which is the one place where fees can be charged
on it.

## Fee shares

The fee is a fraction of the profit, expressed in assets. Paying it in assets would require
pulling funds from the strategy, so the vault mints shares instead. The mint must satisfy
`feeShares / (supply + feeShares) = fee / totalAssets`, which gives
`feeShares = fee * supply / (totalAssets - fee)`. Using `fee * supply / totalAssets` would
under-pay the recipient, because the new shares dilute themselves.

## High-water mark

Losses reported at harvest, and shortfalls during `divest`, accumulate in
`unrecoveredLoss`. Profit first reduces that counter and only the remainder is feeable.
Without it a strategy that oscillates would be charged a fee on every upswing while
depositors make nothing.

## Withdrawal shortfall

The value of the burned shares is fixed before any external call. If idle assets are
insufficient the vault asks the strategy for the difference and measures what arrives. Debt
falls by the amount requested: that amount has left the vault's books either as tokens
received or as a realised loss. The loss is taken out of the withdrawer's payout, subject to
its own `maxLossBps`, so the remaining holders' `totalAssets / totalSupply` is unchanged.

## Pitfalls

- Reading `asset.balanceOf(address(this))` for pricing.
- Trusting the strategy's return value instead of the balance change.
- Reducing debt by the amount received, which leaves phantom debt after a lossy withdrawal
  and pushes the loss onto the remaining holders at the next harvest.
- Charging the fee before netting earlier losses.
- Minting fee shares when the supply is zero.
