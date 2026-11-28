# Patch a Mint Limit Bypass Through onERC721Received

`LimitedMint` is a fixed-price NFT sale. Each address may mint at most `MAX_PER_WALLET` (2)
tokens, the collection is capped at `MAX_SUPPLY` (10) and every token costs `PRICE`
(0.1 ether).

Tokens are minted with a *safe mint*: when the recipient is a contract, the sale calls
`onERC721Received` on it and requires the ERC-721 magic value in return. The sale records how
many tokens the caller has minted only after that callback has returned. A contract can use
the callback to call `mint` again while its counter still reads zero, and walk away with far
more than two tokens. Nested calls can also push `totalSupply` past `MAX_SUPPLY`.

## Your task

Patch `src/LimitedMint.sol` so that no sequence of calls, including calls made from inside
`onERC721Received`, lets an address mint more than `MAX_PER_WALLET` tokens or the collection
exceed `MAX_SUPPLY`. Do not remove the receiver callback: contract wallets must still be able
to mint.

## Interface that must keep working

| Function | Behaviour |
| --- | --- |
| `mint(uint256 quantity)` payable | Mints `quantity` tokens to `msg.sender`. Token ids are sequential starting at 1. |
| `transferFrom(address from, address to, uint256 tokenId)` | Plain transfer by the current token owner. |
| `withdrawProceeds()` | Sends the sale balance to `owner`. |
| `ownerOf(uint256)`, `balanceOf(address)`, `mintedBy(address)`, `totalSupply()` | Public getters. |

`mint` must revert with:

- `ZeroQuantity()` when `quantity == 0`
- `WalletLimitExceeded()` when `mintedBy[msg.sender] + quantity > MAX_PER_WALLET`
- `SoldOut()` when `totalSupply + quantity > MAX_SUPPLY`
- `WrongPayment()` when `msg.value != quantity * PRICE`
- any error when a contract recipient does not return the `onERC721Received` selector

`withdrawProceeds` reverts with `NotOwner()` for anyone but the deployer.

## Rules

- `mintedBy` counts tokens minted by an address, not tokens it currently holds. Transferring a
  token away does not free up allowance, and receiving one does not consume it.
- After any transaction, `mintedBy[a] <= MAX_PER_WALLET` for every address and
  `totalSupply <= MAX_SUPPLY`.
- A nested `mint` from the callback may either revert or be processed against the updated
  count. Both are accepted as long as the limits hold.

## What the tests check

Public tests cover normal minting by an externally owned account and by an honest contract
wallet, the limit across separate calls, wrong payment, and a receiver that re-enters `mint`
from its callback. Hidden tests add a receiver that re-enters with the largest allowed
quantity to attack the supply cap, the difference between minted and held tokens, unsafe
recipients, selling out, and access control on the proceeds.
