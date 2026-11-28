# Reference Solution Explanation

## Conversion

The feed answers "USD per ETH" with `d` decimals. An order of `usd` (18 decimals) costs
`usd / (answer / 10**d)` ETH, which in wei is `usd * 10**d / answer` because the 18 decimals
of the USD amount and of wei cancel. The reference rounds this up with
`(numerator - 1) / price + 1`; `numerator` cannot be zero because zero-priced orders are
rejected at creation. Rounding down would let the customer pay one wei too little on every
order, and would make a sufficiently small order free.

## Feed validation

The answer is checked for `<= 0` before the cast to `uint256`. A zero `updatedAt`, a future
`updatedAt`, and an age above `maxAge` all revert with `StalePrice()`. The same internal
function serves `quote` and `pay`, so the two can never disagree.

## Payment

`pay` follows checks-effects-interactions:

1. existence, then `AlreadyPaid`, then price, then `InsufficientPayment`;
2. `paid`, `payer` and `proceeds` are written;
3. only then is the refund sent.

The refund is an external call to an arbitrary address. If the order were marked paid after
it, a contract payer could call `pay` again from `receive()` and have the gateway account
the same order twice. With the reference ordering the nested call reverts with
`AlreadyPaid()`.

Only `weiDue` is added to `proceeds`. Adding `msg.value` would let the merchant withdraw the
refund as well, draining ETH that belongs to other orders.

A failed refund reverts the whole payment, so a payer that cannot receive ETH must send the
exact amount.

## Withdrawal

`proceeds` is zeroed before the transfer to the merchant, so a re-entrant merchant cannot
withdraw twice.
