# Background: Fixed-Price NFT Marketplaces

## ERC-721 transfers

`transferFrom(from, to, tokenId)` succeeds when the caller is the owner, the address
approved for that token, or an operator approved with `setApprovalForAll`. A marketplace
that escrows tokens is the owner while a listing is open and can therefore send the token
to the buyer or back to the seller without any further approval.

## Push versus pull payments

*Push*: the contract sends ETH to the recipient as part of the operation. If the recipient
is a contract that reverts, the operation fails; if it re-enters, the contract's state may
be half-updated.

*Pull*: the contract records `pending[recipient] += amount` and the recipient later calls
`withdraw()`. A failing recipient only affects its own withdrawal. The withdraw function
follows checks-effects-interactions:

```solidity
uint256 amount = pending[msg.sender];
pending[msg.sender] = 0;                 // effect
(bool ok,) = msg.sender.call{value: amount}("");  // interaction
```

## Basis points

A fee of `f` basis points on a price `p` is `p * f / 10_000`. Integer division rounds
down, so for small prices the fee may be zero. Computing the remainder as `p - fee`
guarantees the parts sum to `p`.

## Parameters that change under a listing

Anything the operator can change between listing and purchase (fee rate, recipient) should
either be captured in the listing or be harmless to the seller. A fee rate is not
harmless; a recipient address is.
