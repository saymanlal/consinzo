# Reference Solution Explanation

## State

- `_owners[tokenId]`: the owner, or `address(0)` when the token does not exist. Because mint
  rejects `address(0)`, existence and "has a non-zero owner" are the same thing, and token id
  `0` needs no special handling.
- `_balances[owner]`: number of tokens held.
- `_tokenApprovals[tokenId]`: the single address approved for that token.

## transferFrom

`ownerOf(tokenId)` is called first and reverts for nonexistent tokens. The remaining checks run
in the specified order: `from` must be the owner, `to` must not be zero, and the caller must be
the owner or the approved address.

The approval is deleted before ownership changes. An approval is permission granted by one
specific owner; if it survived, the previous owner's delegate could pull the token back from the
new owner, including after the token returns to the original owner later.

Balances use `unchecked`: `from` provably holds at least one token, and a balance cannot reach
`2**256`.

## approve

Only the current owner may approve. The approved address can transfer the token but cannot
hand its permission to someone else. Approving `address(0)` is the way to revoke.

## Pitfalls

- Not validating `from` lets an approved caller pass any `from` and corrupts balances.
- Authorising with `msg.sender == from` instead of the stored owner lets anyone "transfer from
  themselves" a token they do not own.
- Returning `address(0)` from `ownerOf` for unminted tokens instead of reverting violates
  EIP-721 and breaks marketplaces that rely on the revert.
