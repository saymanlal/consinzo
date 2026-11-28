# Reference Solution Explanation

## Root cause

Two comparisons used the wrong operator.

```solidity
if (block.timestamp == deadline) revert SaleClosed();      // buy
if (block.timestamp <= deadline) revert SaleStillOpen();   // finalize
```

- `==` is true for a single second. Blocks are not produced every second, so the check
  usually never fires at all, and from `deadline + 1` the sale is open again.
- `<=` treats the deadline second as still open for `finalize`, while the rule says the
  sale is closed from the deadline onwards.

The dangerous combination: the owner finalises and withdraws, buyers keep sending ETH into
a sale that will never be finalised again (`AlreadyFinalized()`), and those funds are
locked.

## Fix

The reference defines the open period once:

```solidity
function _isOpen() internal view returns (bool) {
    return block.timestamp < deadline;
}
```

`buy` requires `_isOpen()` and `finalize` requires `!_isOpen()`. Because both use the same
predicate, every timestamp belongs to exactly one phase and the two functions cannot
drift apart again.

## Pitfalls

- `block.timestamp > deadline` in `buy` closes the sale one second late.
- Fixing only `buy` leaves `finalize` refusing the deadline second. The tests check the
  boundary on both functions.
- Never use `==` or `!=` with `block.timestamp`. Time conditions are ranges.
