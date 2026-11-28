# Reference Solution Explanation

## Root cause

`_purchase` compared `msg.value` with the price of one item. `msg.value` describes the whole
transaction and does not decrease as it is "spent", so inside `buyBatch` the same payment was
accepted once per loop iteration. Five 1 ether tickets cost 1 ether, while `proceeds` grew by
5 ether. The owner's later withdrawal would then either fail or be paid out of funds that do
not exist.

## Fix

`_purchase` no longer looks at `msg.value`. It validates the item, updates stock and
bookkeeping, and returns the price. The two entry points own the payment check:

- `buy` requires `msg.value == _purchase(id)`.
- `buyBatch` accumulates the returned prices and requires `msg.value == total` after the
  loop.

Checking after the loop is safe because a failed check reverts every state change made
inside it. Strict equality keeps `proceeds == address(this).balance` without refund logic.

## Pitfalls

- Using `>=` and keeping the difference silently takes the buyer's change and breaks the
  invariant in the other direction unless the surplus is refunded.
- Tracking a "remaining value" variable works but is easier to get wrong than summing once.
- The same mistake appears when a payable function is reached repeatedly through a
  `delegatecall`-based multicall: every sub-call sees the original `msg.value`.
