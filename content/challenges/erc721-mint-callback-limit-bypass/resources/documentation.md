# Safe-mint callbacks and reentrancy

## Why safe mint calls the recipient

ERC-721 `safeTransferFrom` and the widely used `_safeMint` helper call
`onERC721Received(operator, from, tokenId, data)` when the recipient has code. The recipient
must return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`. This
protects users from sending tokens to contracts that cannot move them, but it is an external
call to an address chosen by the caller.

## The callback is an untrusted call

Everything the recipient can do from an ordinary transaction it can also do from inside the
callback, including calling back into the contract that is in the middle of minting. Any
state that the minting function has checked but not yet written is stale at that moment.
Typical victims are per-wallet counters, allowlist "claimed" flags and supply caps.

## Defences

- **Checks-effects-interactions**: finish every state write the function is responsible for
  before the first external call. For a mint loop this means updating counters for the whole
  quantity before minting the first token.
- **Reentrancy lock**: a storage flag set on entry and cleared on exit. Use non-zero values
  for both states (for example 1 and 2) so that toggling it does not pay the zero-to-non-zero
  storage cost each time.
- Count what you intend to limit. A limit on mints needs a mint counter; a balance is a
  different quantity and changes on transfer.

## Testing idea

Write a receiver whose callback calls `mint` again inside `try/catch`. After the outer call
returns, assert the invariants (`mintedBy <= limit`, `totalSupply <= cap`) rather than
expecting a specific revert. This catches both a missing lock and a misplaced state update.
