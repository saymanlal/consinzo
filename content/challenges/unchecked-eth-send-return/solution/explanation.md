# Reference Solution Explanation

## Root cause

```solidity
balances[msg.sender] = 0;
payable(msg.sender).send(amount);
```

`send` reports failure through its return value. Because the value was discarded, a
failed payment looked exactly like a successful one: the balance stayed at zero while the
ETH remained in the contract with no owner. This is SWC-104, unchecked call return value.

`send` also forwards a fixed 2300 gas stipend, so the failure is easy to trigger by
accident. Any receiver whose `receive` function writes to storage runs out of gas.

## Fix

```solidity
(bool ok, ) = msg.sender.call{value: amount}("");
if (!ok) revert TransferFailed();
```

`call` forwards the remaining gas and the result is checked. The revert also undoes
`balances[msg.sender] = 0`, so the user keeps their claim and can retry.

## Why the balance is still zeroed first

`call` hands control to the receiver with enough gas to call back into `withdraw()`. With
the balance already zero, the re-entrant call hits `NothingToWithdraw()`. Moving the
zeroing after the call to "protect" the balance would reintroduce classic reentrancy.

## Pitfalls

- `require(payable(msg.sender).send(amount))` checks the result but keeps the 2300 gas
  limit, so contract wallets still cannot withdraw. The hidden tests cover this.
- `transfer` has the same gas limit.
- Returning `false` from `withdraw()` instead of reverting leaves the balance wiped unless
  it is restored by hand. Reverting is simpler and cannot be forgotten.
