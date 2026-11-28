# Isolated Lending Markets and Bad Debt

## Isolated versus pooled risk

A pooled money market lets every listed collateral back every listed loan, so a failure of
one collateral can damage every supplier. An isolated market pairs exactly one collateral
with one loan asset. Suppliers choose which risk they take, and a loss stays inside the
market where it happened.

## Share-based accounting

Tracking each user's balance in shares of a growing total avoids iterating over users when
interest accrues. The exchange rate `totalAssets / totalShares` moves; share balances do not.
A virtual share and a virtual asset (adding one to both sides of the ratio) remove the
division by zero when a total is empty and blunt first-depositor rounding games.

## Liquidation incentive

A liquidator receives collateral worth more than the debt repaid. With a bonus factor `b`
(for example `1.1`), seizing collateral valued at `v` repays `v / b`. The borrower pays the
difference. The loan-to-value limit must be low enough that a position becoming unhealthy
still has more than `b` times its debt in collateral under normal price moves.

## Where bad debt comes from

If the price falls faster than liquidators act, collateral value divided by `b` can be less
than the debt. Seizing everything then repays only part of the loan. The remainder has no
collateral behind it. Protocols deal with it in one of three ways: an insurance reserve
pays, the protocol leaves it on the books (and the last suppliers to leave absorb it), or it
is written down across all suppliers at once. This challenge implements the third option,
which is the only one that needs no external capital and treats suppliers equally.

## Rounding rule

For any conversion ask who benefits from the rounding and choose the direction that favours
the market: fewer shares minted to suppliers, fewer assets paid out, more borrow shares
minted, more assets charged for repayment.
