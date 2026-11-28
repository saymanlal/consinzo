# Reference Solution Explanation

## Root cause

`mint` validated `mintedBy[msg.sender] + quantity` and then entered the mint loop. Each
`_safeMint` calls `onERC721Received` on a contract recipient, and `mintedBy` was only
increased after the loop. During the callback the counter was stale, so a nested `mint`
passed the same check again. Because the supply cap was also checked only once per call,
nested calls that each minted one token before re-entering finished their second token on
the way out and pushed `totalSupply` beyond `MAX_SUPPLY`.

## Fix

1. **Checks-effects-interactions.** `mintedBy[msg.sender] += quantity` now happens before the
   loop. A nested call is checked against the final count and fails `WalletLimitExceeded`.
   This alone bounds nesting, which in turn keeps the single supply check valid.
2. **Reentrancy lock on `mint`.** A `nonReentrant` modifier rejects any nested entry. It is
   not strictly required once the ordering is fixed, but it removes the need to reason about
   partially completed loops.

`totalSupply`, `ownerOf` and `balanceOf` were already written before the callback, so token
ids stay unique.

## Pitfalls

- Removing the callback (plain `_mint`) hides the bug but breaks the safe-mint guarantee that
  tokens are not sent to contracts that cannot handle them.
- Checking `balanceOf` instead of `mintedBy` turns the limit into a holding limit, which is
  trivially bypassed by transferring tokens to another address.
- `tx.origin` or "no contracts" checks do not fix the ordering and lock out contract wallets.
