# Token Pull Hub with Expiring, Revocable Allowances

## Problem Statement

Plain ERC-20 allowances never expire and can only be revoked one `(token, spender)` pair at
a time. A pull hub fixes both. Users give the hub one ERC-20 approval per token (usually
unlimited) and then manage fine-grained allowances *inside the hub*: each one is limited in
amount and time, and a single transaction can cut off a spender across every token.

Implement `AllowanceHub` in `src/AllowanceHub.sol`. There are no signatures: an allowance
is granted by its owner calling the hub directly, and a spender is identified by
`msg.sender`. The tokens used by the tests are mocks, including ones that misbehave.

## Interface

```solidity
struct Pull {
    address owner;
    address token;
    address to;
    uint160 amount;
}

function allowance(address owner, address token, address spender)
    external view returns (uint160 amount, uint48 expiration, uint48 epoch);
function nonces(address owner, address spender) external view returns (uint48);
function spendable(address owner, address token, address spender) external view returns (uint160);

function approve(address token, address spender, uint160 amount, uint48 expiration) external;
function revoke(address token, address spender) external;
function revokeSpender(address spender) external returns (uint48 newNonce);

function transferFrom(address owner, address to, uint160 amount, address token) external;
function batchTransferFrom(Pull[] calldata pulls) external;

event Approved(address indexed owner, address indexed token, address indexed spender, uint160 amount, uint48 expiration);
event Revoked(address indexed owner, address indexed token, address indexed spender);
event SpenderRevoked(address indexed owner, address indexed spender, uint48 newNonce);

error ZeroAddress();
error InvalidExpiration();
error AllowanceRevoked();
error AllowanceExpired();
error InsufficientAllowance();
error TransferFailed();
```

## Rules

### Granting

1. `approve(token, spender, amount, expiration)` is called by the owner. It reverts with
   `ZeroAddress()` if `spender == address(0)` and with `InvalidExpiration()` if
   `expiration < block.timestamp`. It **replaces** the stored allowance for
   `(msg.sender, token, spender)` with `amount`, `expiration` and
   `epoch = nonces[msg.sender][spender]`, and emits `Approved`.
2. `nonces[owner][spender]` starts at zero. It is the owner's current *epoch* for that
   spender. An allowance is **live** only while its stored `epoch` equals the current nonce.

### Revoking

3. `revoke(token, spender)` deletes the caller's allowance for that pair (all three fields
   become zero) and emits `Revoked`. It never reverts.
4. `revokeSpender(spender)` increments `nonces[msg.sender][spender]` by one, returns the new
   value and emits `SpenderRevoked`. Every allowance the caller has granted to that spender,
   for every token, stops being live at once. A later `approve` for one token records the
   new epoch and is live; allowances for other tokens stay dead until they are approved
   again.

### Spending

5. `transferFrom(owner, to, amount, token)` is called by the spender. In this order it
   reverts with:
   - `ZeroAddress()` if `to == address(0)`;
   - `AllowanceRevoked()` if the stored `epoch` differs from `nonces[owner][msg.sender]`;
   - `AllowanceExpired()` if `block.timestamp > expiration` (the allowance is still usable
     at exactly `expiration`; an allowance that was never granted has `expiration == 0` and
     therefore fails here);
   - `InsufficientAllowance()` if `amount` exceeds the stored amount.
6. A stored amount of `type(uint160).max` is unlimited and is never decreased. Any other
   stored amount is decreased by `amount` **before** the token is called.
7. The hub then calls `token.transferFrom(owner, to, amount)` and reverts with
   `TransferFailed()` if any of the following holds: `token` has no code, the call reverts,
   or the call returns data that does not decode to `true`. A token that returns no data
   at all is treated as successful (some widely used tokens do this).
8. `batchTransferFrom(pulls)` applies rule 5 to 7 to every entry in order with
   `msg.sender` as the spender. If any entry fails, the whole batch reverts.

### Views

9. `spendable(owner, token, spender)` returns the stored amount if the allowance is live
   and not expired, otherwise `0`. `allowance(...)` returns the raw stored fields.

## What the tests check

- Granting, spending, replacing and the exact expiry boundary.
- Unlimited allowances, per-token and per-spender isolation.
- Both revocation paths, including that a re-approval of one token after `revokeSpender`
  does not revive the spender's allowances for other tokens.
- Batches being atomic and sharing one allowance correctly.
- Tokens that return `false`, return nothing, revert, have no code, or re-enter the hub
  while being transferred.
