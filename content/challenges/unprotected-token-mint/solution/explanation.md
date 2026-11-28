# Reference Solution Explanation

## Root cause

`mint` changed `totalSupply` and `balanceOf` without checking who was calling. Every
other privileged function compared `msg.sender` with `owner`; `mint` was simply missed.

## Fix

The reference adds an `onlyOwner` modifier that reverts with `NotOwner()` and applies it
to both `mint` and `transferOwnership`. Putting the check in a modifier means a future
privileged function gets the same rule by adding one word, instead of re-typing a
condition that can be forgotten again.

## Pitfalls

- Checking `to == owner` instead of `msg.sender == owner` restricts the recipient, not
  the caller. The owner must be able to mint to any address.
- Using `tx.origin` would let a contract the owner interacts with mint on the owner's
  behalf. Always authorise with `msg.sender`.
- Reading `owner` from storage at call time (rather than caching the deployer in an
  `immutable`) is what makes minting rights move with `transferOwnership`.
