# M-of-N Relayer-Attested Bridge with Rate Limits

## Problem Statement

You are building the destination side of a token bridge. Deposits happen on remote chains.
A fixed committee of relayers watches those chains and attests, on this chain, to each
transfer they have seen. Once enough current relayers have attested to exactly the same
transfer, anyone can execute it and the bridge releases tokens from its own liquidity.

Implement `AttestedBridge` in `src/AttestedBridge.sol`. Attestations are address-based: a
relayer attests by calling the contract from its own address. There are no signatures.

Three properties must hold whatever relayers, the owner and third parties do:

- a transfer is released at most once, and a `(source chain, nonce)` pair is consumed at
  most once even if relayers attest to conflicting contents for it;
- only attestations from addresses that are relayers *at execution time* count;
- no more than the configured amount of a token leaves the bridge per rate-limit window.

Tokens and remote chains are mocks and plain numbers inside the test files.

## Interface

```solidity
uint256 public constant WINDOW = 1 hours;

constructor(address[] memory relayers_, uint256 threshold_)

function owner() external view returns (address);            // the deployer
function threshold() external view returns (uint256);
function isRelayer(address account) external view returns (bool);
function relayerCount() external view returns (uint256);

function transferId(uint256 srcChainId, uint256 nonce, address token, address recipient, uint256 amount)
    public view returns (bytes32);

function hasAttested(bytes32 id, address relayer) external view returns (bool);
function attestationCount(bytes32 id) public view returns (uint256);
function executed(bytes32 id) external view returns (bool);
function nonceUsed(uint256 srcChainId, uint256 nonce) external view returns (bool);

function rateLimit(address token) external view returns (uint256);
function availableToRelease(address token) external view returns (uint256);

function attest(uint256 srcChainId, uint256 nonce, address token, address recipient, uint256 amount) external;
function execute(uint256 srcChainId, uint256 nonce, address token, address recipient, uint256 amount) external;

function addRelayer(address relayer) external;
function removeRelayer(address relayer) external;
function setThreshold(uint256 newThreshold) external;
function setRateLimit(address token, uint256 limitPerWindow) external;

error NotOwner();
error NotRelayer();
error ZeroAddress();
error DuplicateRelayer();
error UnknownRelayer();
error InvalidThreshold();
error InvalidTransfer();
error AlreadyAttested();
error AlreadyExecuted();
error NonceAlreadyUsed();
error InsufficientAttestations(uint256 have, uint256 need);
error TokenNotSupported();
error RateLimitExceeded(uint256 requested, uint256 available);
error TransferFailed();
```

## Rules

### Committee

1. Constructor: every relayer must be non-zero (`ZeroAddress()`) and unique
   (`DuplicateRelayer()`); `threshold_` must satisfy `1 <= threshold_ <= relayers_.length`
   (`InvalidThreshold()`).
2. `addRelayer`, `removeRelayer`, `setThreshold`, `setRateLimit` are owner-only (`NotOwner()`).
3. `addRelayer`: `ZeroAddress()`, `DuplicateRelayer()` if already a relayer.
4. `removeRelayer`: `UnknownRelayer()` if not a relayer; `InvalidThreshold()` if removal
   would leave fewer relayers than `threshold`.
5. `setThreshold`: `InvalidThreshold()` unless `1 <= newThreshold <= relayerCount()`.

### Transfers

6. `transferId` is
   `keccak256(abi.encode(srcChainId, block.chainid, address(this), nonce, token, recipient, amount))`.
7. `attest` checks, in order: caller is a relayer (`NotRelayer()`); `token`, `recipient`
   non-zero and `amount` non-zero (`InvalidTransfer()`); the id is not executed
   (`AlreadyExecuted()`); the caller has not attested to this id (`AlreadyAttested()`).
   It then records the attestation. It never moves tokens.
8. `attestationCount(id)` is the number of **current** relayers that attested to `id`.
   An attestation by an address that has since been removed does not count; if that address
   is added again, its old attestation counts again.
9. `execute` can be called by anyone and checks, in order:
   - `AlreadyExecuted()` if this id was executed;
   - `NonceAlreadyUsed()` if another transfer with the same `(srcChainId, nonce)` was executed;
   - `InsufficientAttestations(have, need)` if `attestationCount(id) < threshold`;
   - `TokenNotSupported()` if `rateLimit[token] == 0`;
   - `RateLimitExceeded(amount, available)` if `amount > availableToRelease(token)`.

   It then marks the id executed and the nonce used, charges the rate limit and calls
   `token.transfer(recipient, amount)`, reverting with `TransferFailed()` if that returns
   `false`. All state is written before the token is called.
10. A transfer blocked by the rate limit is not consumed: it can be executed in a later
    window without new attestations.

### Rate limit

11. `setRateLimit(token, limitPerWindow)` sets the maximum amount of `token` released per
    window. Zero disables the token. Changing the limit does not reset the current window.
12. Each token has a window start and an amount spent in that window. On `execute`, if
    `block.timestamp >= windowStart + WINDOW` a new window starts at `block.timestamp`
    with nothing spent (the first execution for a token always starts a window).
13. `availableToRelease(token)` returns what `execute` could release now: `rateLimit[token]`
    if the window has expired (or never started), otherwise `rateLimit[token] - spent`, or
    `0` if the limit has been lowered below what is already spent.

## What the tests check

- Threshold counting, duplicate attestations, non-relayers.
- Replay of an executed transfer and conflicting transfers for one nonce.
- Removing, re-adding relayers and changing the threshold between attestation and execution.
- Rate-limit boundaries, window rollover, deferred execution, limit changes.
- A token that returns `false` and a token that calls back into `execute`.
