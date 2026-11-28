# Safe Transfers in ERC-721

## The problem

`transferFrom` assigns a token to any non-zero address. If that address is a contract with no
code path to transfer NFTs, the token is locked forever. EIP-721 calls `transferFrom` the
caller's responsibility and adds a safe variant.

## What EIP-721 specifies

`safeTransferFrom(from, to, tokenId, data)` performs the transfer and then, when `to` is a smart
contract (code size greater than zero), calls

```solidity
function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
    external returns (bytes4);
```

on it. The transfer must be reverted unless the return value is
`bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`, which is `0x150b7a02`.
The overload without `data` behaves the same with empty data.

`safeMint` is not part of the standard interface but is the same idea applied to minting, with
`from` set to the zero address.

## Detecting contracts

`address.code.length` is the size of the code stored at an address. It is zero for externally
owned accounts and also for a contract whose constructor is still running.

## try/catch

`try target.f(args) returns (T v) { ... } catch { ... }` executes an external call and handles
its failure in the `catch` block instead of propagating the revert. Only the external call
itself is covered: a revert raised inside the `try` success block propagates normally.

## Callbacks and state

Any callback to an untrusted address is a reentrancy point. The safe pattern is to finish every
state change first, so that whatever the callee does, it interacts with a consistent contract.
