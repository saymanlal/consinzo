# Reference Solution Explanation

## Accounting

The pool never reads its token balance to make a decision. It keeps three counters:

| counter        | meaning                                   | belongs to |
| -------------- | ----------------------------------------- | ---------- |
| `idle`         | cash available now                        | LPs        |
| `outstanding`  | cash paid out, awaiting reimbursement     | LPs        |
| `protocolFees` | realised protocol share of fees           | protocol   |

`totalAssets = idle + outstanding`. Because the counters only move inside the pool's own
functions, sending tokens to the pool cannot inflate the share price (the classic
first-depositor attack) and cannot be used to front transfers.

## Fee recognition

`fulfill` converts `paid` of cash into `paid` of receivable, so `totalAssets` is unchanged.
The fee appears only when `settle` brings back `amount > paid`. Recognising the fee at
fulfilment would raise the share price on the strength of money that has not arrived, and
an LP could withdraw that paper profit out of other LPs' idle cash.

At settlement the fee is `amount - fronted` (using the stored figure, not a recomputation,
so it always matches what actually left the pool). The protocol cut is carved out of the
fee and the rest stays in `idle`.

## Transfer state

`None -> Fulfilled -> Settled` on the fast path, `None -> Settled` on the slow path.

- `fulfill` requires `None`. This rejects a second fulfilment and, more importantly, a
  fulfilment after the slow path already paid the user in full; that case would never be
  reimbursed.
- `settle` rejects `Settled`. For a fulfilled transfer it also compares
  `keccak256(recipient, amount)` with the hash stored at fulfilment. A smaller amount would
  under-repay the pool; a different recipient means the two sides disagree about the
  transfer and the settlement must not be absorbed silently.

## Withdrawals

Share value is computed from `totalAssets`, but only `idle` can leave. An LP exiting while
capital is outstanding is paid at cost and forgoes the pending fee; the reference does not
try to queue withdrawals.

## Rounding

Shares minted round down and assets paid out round down. Both favour the LPs who stay, so
repeated deposit/withdraw cycles cannot extract value. A deposit that would mint zero
shares is refused rather than accepted as a gift.

## Pitfalls

- `totalAssets = token.balanceOf(address(this))`: counts protocol fees as LP value, ignores
  outstanding capital (share price collapses during a fulfilment) and is donation-prone.
- Checking `paid <= token.balanceOf(address(this))` in `fulfill`: spends protocol fees.
- Allowing `fulfill` after a slow-path `settle`.
- Recomputing the fee at settlement from the settlement amount without checking it equals
  the fulfilled amount.
