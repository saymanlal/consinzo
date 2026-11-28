# Supply Caps

## Why cap supply

A mint function gives its caller the power to dilute every holder. A hard cap written into the
contract bounds that power: holders can verify on-chain that no more than `cap` tokens can ever
exist at once, whatever the owner does.

## Immutable variables

A state variable declared `immutable` is assigned in the constructor and then fixed. The value
is stored in the deployed bytecode rather than in a storage slot, so reading it is cheap and no
later transaction can modify it.

## Checked arithmetic and comparison order

Solidity 0.8 reverts with `Panic(0x11)` on overflow. When validating `a + b <= limit` with
untrusted `b`, rewrite it as `b <= limit - a` whenever `a <= limit` is already guaranteed. The
subtraction cannot underflow and no intermediate value exceeds `limit`.

## Mint and burn events

EIP-20 recommends emitting `Transfer(address(0), to, amount)` when tokens are created. Burning is
conventionally `Transfer(from, address(0), amount)`. Wallets and indexers reconstruct balances
and supply from these events.
