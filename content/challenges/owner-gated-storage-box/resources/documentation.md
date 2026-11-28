# Owner-Gated State: Background

## State variables and visibility

A `public` state variable gets an automatic getter, which is why `owner()` and `updateCount()` need
no hand-written function. A `private` variable has no getter, so `get()` exposes it explicitly.
Private only hides the variable from other contracts; the data is still readable on chain.

## msg.sender

`msg.sender` is the immediate caller of the current function. In a constructor it is the deploying
account. Access checks compare `msg.sender` with a stored address. `tx.origin` is the externally
owned account that started the transaction and must not be used for authorization.

## Custom errors

```solidity
error NotOwner(address caller);
...
if (msg.sender != owner) revert NotOwner(msg.sender);
```

The revert data is the 4-byte selector of the error followed by its ABI-encoded arguments. Tests
and front ends can decode it.

## immutable

An `immutable` variable is assigned once in the constructor and then baked into the deployed
bytecode. It suits values such as an owner that is fixed for the life of the contract.
