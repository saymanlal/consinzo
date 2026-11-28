# ERC-721 Safe Transfers and the Receiver Check

## Problem Statement

An NFT sent to a contract that cannot move it is lost. ERC-721 therefore defines *safe*
transfers: when the recipient is a contract, the token calls `onERC721Received` on it and
requires a specific return value. Implement `SafeNFT` in `src/SafeNFT.sol` with safe transfers
and safe mints.

The starter declares the `IERC721Receiver` interface and the contract's storage, events and
errors.

## Required Interface

```solidity
function minter() external view returns (address);                       // the deployer
function ownerOf(uint256 tokenId) external view returns (address);       // NonexistentToken()
function balanceOf(address owner) external view returns (uint256);       // ZeroAddress()
function getApproved(uint256 tokenId) external view returns (address);   // NonexistentToken()
function isApprovedForAll(address owner, address operator) external view returns (bool);

function approve(address approved, uint256 tokenId) external;
function setApprovalForAll(address operator, bool approved) external;
function transferFrom(address from, address to, uint256 tokenId) external;
function safeTransferFrom(address from, address to, uint256 tokenId) external;
function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
function safeMint(address to, uint256 tokenId) external;
function safeMint(address to, uint256 tokenId, bytes calldata data) external;

error NotMinter();
error ZeroAddress();
error AlreadyMinted();
error NonexistentToken();
error NotAuthorized();
error WrongOwner();
error UnsafeRecipient();
```

## Rules

### Authorisation and plain transfers

1. A caller is *authorised* for a token if it is the owner, the token's approved address, or an
   operator of the owner (`isApprovedForAll(owner, caller)`).
2. `approve(approved, tokenId)`: `NonexistentToken()` if unminted; `NotAuthorized()` unless the
   caller is the owner or an operator of the owner. Emits `Approval(owner, approved, tokenId)`.
3. `setApprovalForAll(operator, approved)` sets the flag for `msg.sender` and emits
   `ApprovalForAll(msg.sender, operator, approved)`.
4. `transferFrom(from, to, tokenId)`: `NonexistentToken()`; then `WrongOwner()` if `from` is not
   the owner; then `ZeroAddress()` if `to == address(0)`; then `NotAuthorized()` if the caller
   is not authorised. Clears the token approval, updates balances and owner, emits `Transfer`.
   It performs **no** receiver check.

### Safe transfers and mints

5. `safeTransferFrom` (both overloads) does everything `transferFrom` does and then performs
   the receiver check. The three-argument overload uses empty `data`.
6. `safeMint` (both overloads): `NotMinter()` unless the caller is the deployer; `ZeroAddress()`
   for the zero recipient; `AlreadyMinted()` if the token exists. It assigns the token, emits
   `Transfer(address(0), to, tokenId)` and then performs the receiver check with
   `from = address(0)`.
7. **Receiver check.** If `to` has no code (`to.code.length == 0`) nothing is called. Otherwise
   call

   ```solidity
   IERC721Receiver(to).onERC721Received(operator, from, tokenId, data)
   ```

   where `operator` is `msg.sender` of the token call. The transfer is accepted only if the call
   succeeds and returns `IERC721Receiver.onERC721Received.selector` (`0x150b7a02`). If the call
   reverts or returns any other value, revert with `UnsafeRecipient()`. A recipient contract
   that does not implement the function at all must also make the call revert.
8. The hook is called **after** ownership, balances and approvals have been updated, so the
   recipient already owns the token during the hook and may transfer it onward. A failed check
   reverts the whole transaction, leaving the token with its previous owner (or unminted).

## What the Tests Check

Public tests cover a safe transfer to an EOA, to an accepting contract and to a contract with no
hook. Hidden tests cover the hook arguments for transfers and mints, wrong return values,
reverting receivers, state visible inside the hook, onward transfers from inside the hook,
operators, and that `transferFrom` skips the check.
