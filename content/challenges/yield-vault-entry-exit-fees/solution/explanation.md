# Reference Solution Explanation

## Accounting model

Three numbers describe the pool: `totalAssets` (assets backing the shares), `totalSupply`
(shares) and the per-user share balances. The share price is `totalAssets / totalSupply`.

- **Deposit.** `fee = assets * depositFeeBps / 10_000`. Only `net = assets - fee` joins the
  pool, and the depositor receives `net * totalSupply / totalAssets` shares, priced on the
  state before the deposit. The fee goes straight to the recipient, so existing holders are
  neither diluted nor subsidised.
- **Redeem.** `gross = shares * totalAssets / totalSupply`. The gross amount leaves
  `totalAssets`; `fee = gross * withdrawFeeBps / 10_000` goes to the recipient and the rest to
  the user. Removing the gross amount keeps the price of the remaining shares unchanged.
- **Yield.** `addYield` raises `totalAssets` without minting, which raises the price.

All divisions round down, in the vault's favour: a depositor gets at most the fair number of
shares and a redeemer at most the fair amount of assets. When the last shares are redeemed,
`gross == totalAssets`, so the vault empties exactly.

## Internal asset tracking

`totalAssets` is a storage variable. Reading `asset.balanceOf(address(this))` instead would let
anyone move the share price with a plain transfer. Combined with the 1:1 first deposit, that is
the classic inflation attack: mint one share, donate a large amount, and make the next
depositor's shares round down to zero.

The only way to raise the price here is `addYield`, and two guards make that harmless:

- `ZeroShares()` rejects a deposit that would mint nothing, so a victim cannot lose a whole
  deposit to rounding;
- `NoShareholders()` rejects yield when nobody holds shares, because the next depositor would
  otherwise receive it for free through the 1:1 rule.

Rounding losses below one share's price remain possible when the price is extremely high; a
production vault adds virtual shares or a minimum first deposit on top of this.

## Pitfalls

- Adding the full `assets` (fee included) to `totalAssets` while sending the fee out makes the
  vault insolvent by the fee.
- Subtracting only the user's net amount on redeem leaves the fee counted as pool assets that
  are no longer there.
- Charging the withdrawal fee on shares instead of on the gross asset value changes the
  rounding and the documented amounts.
- Transferring a zero fee wastes gas and fails with tokens that reject zero transfers.
