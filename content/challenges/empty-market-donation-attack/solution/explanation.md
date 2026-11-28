# Why the patch works

The exploit needs three things at once. The reference removes each of them.

## 1. Donations no longer count

The starter computes `cash(id)` as `token.balanceOf(address(this))`. A share's value is
`(cash + borrows) / totalShares`, so anybody can raise it by transferring tokens to the
contract. In a live market that costs the donor money, because the gain is shared with every
supplier. In an *empty* market the attacker is the only supplier and can shrink the share
supply to 2 wei first, so the donation is fully theirs and each wei of shares becomes
enormous collateral.

The reference keeps `_cash[id]` and changes it only in `_pullIn` (mint, repay) and when
tokens leave (redeem paths, borrow). A plain transfer is invisible to the rate. With the
exploit's inputs the attacker's 2 wei of shares are worth 2 wei.

## 2. `redeemUnderlying` rounds up

When the caller chooses the amount out, the contract chooses the shares in. Rounding that
down lets the caller pay less than the amount is worth. With 2 shares worth 500 tokens each,
`1000e18 * 2 / (1000e18 + 2)` floors to 1, so 1000 tokens leave for one share. The reference
uses `ceil(amount * totalShares / totalAssets)`. The same rounding stops 1-wei withdrawals
from being free whenever the rate is above `1e18`.

## 3. Health is evaluated after the books are final

The starter checks solvency after burning shares but while the outgoing tokens are still in
the contract, so with balance-based cash they still count as collateral. The reference
subtracts the amount from `_cash` before calling `_requireHealthy`, then transfers.

## Pitfalls

- Fixing only the rounding still lets the donation back a borrow; the attacker simply
  abandons the donation if the borrow is larger. Internal accounting is the essential fix.
- Minting "dead shares" to the zero address mitigates inflation in vaults but does not make
  a balance-based rate safe as collateral in a lending market.
- `mint` and `redeem` must keep rounding down. Rounding always goes against the caller.
