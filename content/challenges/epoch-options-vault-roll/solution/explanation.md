# Reference Solution Explanation

## One settlement price per epoch

`roll` computes the value of the locked assets after the premium and payout and divides by
the share supply. That price is used twice in the same call: queued shares leave at it, and
pending assets enter at it. Because both conversions use the price that already includes the
epoch's result, leavers carry the result and joiners do not.

## Lazy conversion

Minting shares to every depositor inside `roll` would need a loop. Instead the roll mints
the aggregate amount into `totalShares` and stores the price under the epoch number. A user
converts its own deposit later with the stored price (`_redeem`), and `shareBalanceOf`
reports the balance as if that had already happened. Every function that needs the user's
shares calls `_redeem` first.

The same idea is used for withdrawals: the roll moves the aggregate amount into
`withdrawalReserve`, and each user computes its payment from the stored price of its request
epoch. The reserve is no longer part of `lockedAssets`, so later losses cannot touch it.

## Rounding

Aggregates and per-user amounts both round down. Since `floor(a + b) >= floor(a) + floor(b)`,
the aggregate shares minted cover all individual redemptions and the aggregate reserve covers
all individual payments. Dust stays in the vault.

## Guards

- With no shares there is nothing at risk, so a premium or payout is rejected rather than
  being credited to nobody.
- The payout must leave a positive price; a zero price would make deposit conversion divide
  by zero.
- An unclaimed request from an older epoch has its own price and cannot be merged with a new
  request, so the new request is refused until the old one is completed.

## Pitfalls

- Converting pending deposits at the price before the premium gives depositors yield they
  did not earn.
- Paying withdrawals out of locked assets at claim time exposes them to later epochs.
- Allowing `cancelDeposit` after the roll returns assets that are already backing shares.
