# Reference Solution Explanation

## Root cause

```solidity
function _setOwner(address newOwner) public { ... }
```

A `public` function is part of the contract's ABI and gets a selector. The underscore
prefix signals "internal" to human readers only. Because the caller check lived in
`transferOwnership` and not in the helper, calling `_setOwner` directly bypassed it.

## Fix

The helper is declared `internal`. The compiler no longer generates a selector for it, so
an external call with `_setOwner(address)` calldata matches no function and reverts. The
constructor and `transferOwnership` still reach it by an internal jump.

The reference also moves the caller check into an `onlyOwner` modifier so both privileged
functions share one implementation.

## Alternative that also passes

Keeping the helper `public` and adding the owner check inside it closes the hole too, but
it leaves two external ways to do the same thing and breaks the constructor unless the
initial owner is assigned differently. Removing the entry point is the smaller surface.

## Pitfalls

- `private` works for this contract but prevents derived contracts from reusing the
  helper. `internal` is the conventional choice.
- Do not forget the constructor: it runs before `owner` is set, so an owner check placed
  inside the helper would revert at deployment.
