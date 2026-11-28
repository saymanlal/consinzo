# Reference Solution Explanation

## Root cause

`withdrawAll()` read the contract balance and sent it to `msg.sender` with no
authorisation. `owner` was stored but never consulted. This is SWC-105, unprotected
ether withdrawal.

## Fix

```solidity
if (msg.sender != owner) revert NotOwner();
```

is now the first statement. The reference also pays `owner` instead of `msg.sender`.
After the check the two are equal, but naming the stored owner as the destination makes
the intent explicit and stays correct if the authorisation rule is ever extended (for
example to let a keeper trigger the sweep).

## Pitfalls

- Placing the owner check after the `NothingToWithdraw()` check makes the error a stranger
  sees depend on the jar's state. The README requires `NotOwner()` first.
- `tx.origin == owner` is not a fix: a contract the owner calls could then sweep the jar.
- `transfer`/`send` forward only 2300 gas and break if the owner is a contract wallet.
  Keep the low-level `call` and check its return value.
