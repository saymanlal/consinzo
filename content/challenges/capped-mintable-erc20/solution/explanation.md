# Reference Solution Explanation

## The cap check

The invariant is `totalSupply <= cap`. The obvious check is

```solidity
if (totalSupply + amount > cap) revert CapExceeded();
```

but `totalSupply + amount` is evaluated first. For a huge `amount` the addition overflows and
Solidity 0.8 raises `Panic(0x11)`, so the caller gets the wrong error. In an `unchecked` block
or an older compiler it would wrap around and the check would pass, minting past the cap.

The reference rearranges the inequality so nothing can overflow:

```solidity
if (amount > cap - totalSupply) revert CapExceeded();
```

`cap - totalSupply` is safe because of the invariant itself. After the check,
`totalSupply + amount <= cap`, so the additions are done in `unchecked`.

## Other points

- `cap` and `owner` are `immutable`: they are written once in the constructor and embedded in
  the runtime bytecode, so they cost no storage read and cannot be changed.
- Check order in `mint` is caller, recipient, cap. A non-owner always sees `NotOwner()`.
- `burn` lowers `totalSupply`, so it frees room. If a design needs a lifetime cap instead, it
  must track a separate `totalMinted` counter.

## Pitfalls

- Checking the cap after updating state still reverts, but the order makes the code harder to
  reason about and easy to break later.
- Using `>=` instead of `>` makes the last token unmintable.
- Capping `balanceOf[to]` instead of `totalSupply`.
