# Reference Solution Explanation

## Root cause

`init` plays the role of a constructor, but unlike a constructor it is an ordinary
external function that stays callable for the lifetime of the contract. The starter wrote
`initialized = true` and never read it, so a second call simply overwrote `owner`.

## Fix

```solidity
if (initialized) revert AlreadyInitialized();
if (owner_ == address(0)) revert ZeroAddress();
initialized = true;
owner = owner_;
```

The guard is unconditional. It does not ask who is calling, because there is no
legitimate second call: letting the owner re-run `init` would turn a setup function into
an undocumented ownership transfer.

## Pitfalls

- `if (owner != address(0)) revert ...` is a workable guard here, but it ties
  initialisation to one field. As soon as `init` sets several values, or ownership can be
  renounced, the dedicated flag is the reliable signal.
- Restricting `init` to `msg.sender == owner` fails on the very first call (the owner is
  still zero) or, written as "owner is zero or caller is owner", allows re-initialisation.
- An initialiser that is not called in the same transaction as deployment can be
  front-run by anyone. Factories should deploy and initialise atomically. That is outside
  the code you can change here, but it is the reason initialisers need extra care.
