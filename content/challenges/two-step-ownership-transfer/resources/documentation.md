# Ownership and Modifiers: Background

## The single-owner pattern

Many contracts keep an `owner` address and restrict administrative functions to it. EIP-173
standardises the read function `owner()` and the event
`OwnershipTransferred(previousOwner, newOwner)`, emitted with `previousOwner == address(0)` at
deployment.

## Why two steps

A direct `transferOwnership(newOwner)` takes effect immediately. If the address is wrong, or
belongs to a contract that cannot call the owner functions, control is lost permanently. With a
propose/accept handshake the new owner has to send a transaction from the proposed address before
anything changes, which proves the address works.

## Modifiers

```solidity
modifier onlyOwner() {
    if (msg.sender != owner) revert NotOwner(msg.sender);
    _;
}
```

A modifier wraps a function body. The `_;` marks where the body runs. Code before it executes
first, so a modifier that reverts acts as a precondition. Modifiers listed on a function run in the
order they are written.

## delete

`delete pendingOwner;` resets the variable to `address(0)`. Clearing one-time authorisations after
use is a general rule: an approval that stays in storage can be used again.
