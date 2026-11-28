# Reference Solution Explanation

## Constructor

The constructor is the only place supply is created. It writes `totalSupply` and the deployer's
balance and emits `Transfer(address(0), msg.sender, initialSupply)`, which is how indexers
recognise a mint. `msg.sender` in a constructor is the account (or contract) that sent the
deployment transaction.

## Transfer

1. `to == address(0)` is rejected. Tokens sent there are unrecoverable, and `Transfer` to the
   zero address is reserved for burns, which this token does not have.
2. The sender's balance is read once and compared to `amount`; the subtraction is then safe
   inside `unchecked`.
3. The debit is written to storage before the credit is applied with `+=`. With this ordering a
   self-transfer subtracts and then adds the same amount to the same slot.

## Pitfalls

- Caching both balances and writing `balanceOf[to] = toBalance + amount` last turns a
  self-transfer into a free mint.
- Relying on the checked-arithmetic `Panic(0x11)` for the balance check works but gives callers
  no usable error; the specification asks for `InsufficientBalance()`.
- Rejecting zero-amount transfers breaks integrations: EIP-20 says transfers of 0 must be
  treated as normal transfers.
