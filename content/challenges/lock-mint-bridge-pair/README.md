# Lock-and-Mint Bridge Pair

## Problem Statement

A lock-and-mint bridge keeps the canonical token in a vault on the source chain and issues a
wrapped representation on the destination chain. A trusted relayer watches each side and
carries events to the other: a lock becomes a mint, a burn becomes a release.

Implement both ends in `src/LockMintBridge.sol`:

- `SourceVault` – holds the canonical ERC-20 on the source chain;
- `WrappedToken` – the wrapped ERC-20 on the destination chain.

The two chains are modelled as two contracts in the same test. The test plays the relayer
and copies nonces and amounts from one side to the other. The ERC-20 plumbing of
`WrappedToken` (`transfer`, `approve`, `transferFrom`) is already in the starter.

## Interface

```solidity
// SourceVault
constructor(address token_, address relayer_)
function token() external view returns (IERC20Like);
function relayer() external view returns (address);
function depositCount() external view returns (uint256);
function totalLocked() external view returns (uint256);
function processedBurns(uint256 burnNonce) external view returns (bool);
function lock(uint256 amount, address recipient) external returns (uint256 depositNonce);
function release(uint256 burnNonce, address recipient, uint256 amount) external;

// WrappedToken
constructor(address relayer_)
function relayer() external view returns (address);
function burnCount() external view returns (uint256);
function processedDeposits(uint256 depositNonce) external view returns (bool);
function mint(uint256 depositNonce, address to, uint256 amount) external;
function burn(uint256 amount, address recipient) external returns (uint256 burnNonce);

event Locked(uint256 indexed depositNonce, address indexed sender, address indexed recipient, uint256 amount);
event Released(uint256 indexed burnNonce, address indexed recipient, uint256 amount);
event Minted(uint256 indexed depositNonce, address indexed to, uint256 amount);
event Burned(uint256 indexed burnNonce, address indexed sender, address indexed recipient, uint256 amount);

error ZeroAddress();
error ZeroAmount();
error NotRelayer();
error AlreadyProcessed();
error InsufficientLocked();
error InsufficientBalance();
error TransferFailed();
```

Both contracts declare the errors they use; the names and signatures above are shared.

## Rules

### SourceVault

1. The constructor reverts with `ZeroAddress()` if either argument is zero.
2. `lock(amount, recipient)` reverts with `ZeroAmount()` if `amount == 0` and with
   `ZeroAddress()` if `recipient == address(0)`. It pulls `amount` of `token` from the caller
   with `transferFrom` (reverting with `TransferFailed()` if the call returns `false`),
   increases `totalLocked`, increments `depositCount` and returns the new value. The first
   deposit has nonce 1. Emits `Locked`.
3. `release(burnNonce, recipient, amount)` is called by the relayer after a burn on the
   destination. Checks, in this order: caller is the relayer (`NotRelayer()`),
   `recipient != address(0)` (`ZeroAddress()`), `amount != 0` (`ZeroAmount()`), the burn
   nonce has not been released before (`AlreadyProcessed()`), `amount <= totalLocked`
   (`InsufficientLocked()`). It marks the nonce, decreases `totalLocked` and transfers the
   tokens (`TransferFailed()` if `transfer` returns `false`). Emits `Released`.
4. `totalLocked` tracks deposits made through `lock` only. Tokens sent to the vault directly
   are not counted and can never be released.

### WrappedToken

5. The constructor reverts with `ZeroAddress()` if `relayer_` is zero. `name` is
   `"Wrapped Bridged Token"`, `symbol` is `"wBRG"`, `decimals` is 18.
6. `mint(depositNonce, to, amount)` – checks in this order: caller is the relayer
   (`NotRelayer()`), `to != address(0)` (`ZeroAddress()`), `amount != 0` (`ZeroAmount()`),
   the deposit nonce has not been minted before (`AlreadyProcessed()`). It marks the nonce
   and mints. Emits `Minted` and `Transfer(address(0), to, amount)`.
7. `burn(amount, recipient)` – reverts with `ZeroAmount()`, `ZeroAddress()` (zero
   `recipient`, the address that receives the canonical token on the source chain) or
   `InsufficientBalance()`. It burns from the caller, increments `burnCount` and returns
   the new value (first burn is nonce 1). Emits `Burned` and `Transfer(msg.sender, address(0), amount)`.

When the relayer has delivered every message, `WrappedToken.totalSupply()` equals
`SourceVault.totalLocked()`.

## What the tests check

- A full round trip: lock, mint, transfer of the wrapped token, burn, release.
- Nonce sequencing on both sides and replay protection for mints and releases.
- Access control, zero-value checks, check ordering, and the supply/locked invariant across
  interleaved operations, including out-of-order relaying.
