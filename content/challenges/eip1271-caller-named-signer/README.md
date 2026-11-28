# Bind EIP-1271 Validation to the Account That Owns the Funds

`SignedWithdrawVault` holds ETH for smart-contract wallets. A wallet can withdraw directly,
or it can approve a withdrawal off-chain and let any relayer submit it with
`withdrawWithSignature`. Because wallets are contracts, approval is checked with EIP-1271:
the vault calls `isValidSignature(hash, signature)` and expects the magic value `0x1626ba7e`.

An account may also register delegate signer contracts (for example a session-key module)
with `setDelegate`.

## The bug

`withdrawWithSignature` takes the signer contract as an argument from the relayer and asks
that contract. It never checks that the signer has anything to do with the account being
debited. An attacker deploys a contract whose `isValidSignature` always returns the magic
value, names it as signer, and withdraws any account's balance to themselves.

## Your task

Patch `src/SignedWithdrawVault.sol`. Keep the interface unchanged.

```solidity
struct Withdrawal { address account; address to; uint256 amount; uint256 nonce; uint256 deadline; }

function deposit() external payable;
function withdraw(uint256 amount) external;
function setDelegate(address signer, bool allowed) external;
function hashWithdrawal(Withdrawal calldata w) external view returns (bytes32);
function withdrawWithSignature(Withdrawal calldata w, address signer, bytes calldata signature) external;
```

### Required behaviour of `withdrawWithSignature`

Checks, in this order:

1. `block.timestamp > w.deadline` reverts with `Expired()`.
2. `w.nonce != nonces[w.account]` reverts with `InvalidNonce()`.
3. `signer` must be `w.account` itself or an address for which
   `isDelegate[w.account][signer]` is true; otherwise `UnauthorizedSigner()`.
4. The signer must accept the hash: a `staticcall` to
   `isValidSignature(hashWithdrawal(w), signature)` must succeed and return at least 32 bytes
   whose first word is the magic value left-aligned. Anything else, including a signer that
   reverts, returns short data, returns another value or has no code, reverts with
   `InvalidSignature()`. Errors of the signer are not bubbled up.
5. `w.amount` above the account's balance reverts with `InsufficientBalance()`.

On success the nonce is incremented and the balance reduced before `w.amount` wei are sent
to `w.to`.

`hashWithdrawal` is already correct and must stay
`keccak256(abi.encode(WITHDRAWAL_TYPEHASH, block.chainid, address(this), w.account, w.to, w.amount, w.nonce, w.deadline))`.

## What the tests check

- An always-valid signer named by the caller cannot move a wallet's funds.
- Another honest wallet, or another account's delegate, cannot authorise either.
- The account itself and its current delegates can; revoked delegates cannot.
- Hostile signer contracts produce `InvalidSignature()`; replay, expiry and field binding.
