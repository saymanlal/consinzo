# Hashed Timelock Contract for Atomic Swaps

## Problem Statement

Two parties on two chains can exchange assets without trusting each other or a bridge by
using a hashed timelock contract (HTLC) on each chain. Alice picks a secret `s` and locks
her asset for Bob on chain A under `H = sha256(s)`. Bob locks his asset for Alice on
chain B under the same `H` with a shorter timeout. When Alice claims on chain B she has to
publish `s`, which lets Bob claim on chain A. If either side stops, both locks time out
and are refunded.

Implement `HashedTimelock` in `src/HashedTimelock.sol`. One deployment holds many swaps
and supports ETH and ERC-20 tokens. In the tests the "two chains" are two deployments of
your contract.

## Interface

```solidity
enum State { None, Open, Claimed, Refunded }

function swaps(bytes32 swapId) external view returns (
    address sender, address recipient, address token, uint256 amount,
    bytes32 hashlock, uint64 timelock, State state
);
function preimageOf(bytes32 swapId) external view returns (bytes32);
function computeSwapId(
    address sender, address recipient, address token, uint256 amount, bytes32 hashlock, uint64 timelock
) external pure returns (bytes32);

function lockETH(address recipient, bytes32 hashlock, uint64 timelock)
    external payable returns (bytes32 swapId);
function lockToken(address token, uint256 amount, address recipient, bytes32 hashlock, uint64 timelock)
    external returns (bytes32 swapId);
function claim(bytes32 swapId, bytes32 preimage) external;
function refund(bytes32 swapId) external;

event Locked(bytes32 indexed swapId, address indexed sender, address indexed recipient,
             address token, uint256 amount, bytes32 hashlock, uint64 timelock);
event Claimed(bytes32 indexed swapId, bytes32 preimage);
event Refunded(bytes32 indexed swapId);

error ZeroAddress();
error ZeroAmount();
error InvalidTimelock();
error SwapExists();
error SwapNotOpen();
error Expired();
error NotExpired();
error InvalidPreimage();
error TransferFailed();
```

## Rules

### Identifiers

1. `computeSwapId` returns
   `keccak256(abi.encode(sender, recipient, token, amount, hashlock, timelock))`.
   ETH swaps use `token == address(0)`. `amount` is the amount passed by the sender
   (`msg.value` for ETH).

### Locking

2. `lockETH` and `lockToken` check, in order:
   - `recipient != address(0)` and, for `lockToken`, `token != address(0)` → `ZeroAddress()`;
   - the amount (`msg.value` or `amount`) is not zero → `ZeroAmount()`;
   - `timelock > block.timestamp` → `InvalidTimelock()`;
   - no swap with this id was ever created, whatever its current state → `SwapExists()`.
3. `lockToken` pulls the tokens with `transferFrom`. The swap's stored `amount` is the
   number of tokens the contract **actually received** (its balance increase), which is
   lower than the requested amount for fee-on-transfer tokens. Receiving nothing reverts
   with `TransferFailed()`.
4. Token transfers must work with tokens that return `true`, and with tokens that return
   no data at all. A token call that reverts or returns `false` causes `TransferFailed()`.
5. A new swap is `Open` with `sender = msg.sender`.

### Claiming

6. `claim` may be called by anyone; the funds always go to the swap's `recipient`. Checks,
   in order:
   - the swap is `Open` → otherwise `SwapNotOpen()` (also for unknown ids);
   - `block.timestamp < timelock` → otherwise `Expired()`;
   - `sha256(abi.encodePacked(preimage)) == hashlock` → otherwise `InvalidPreimage()`.
7. A successful claim sets the state to `Claimed`, stores the preimage in `preimageOf`
   and pays the stored amount to the recipient.

### Refunding

8. `refund` may be called by anyone; the funds always go to the swap's `sender`. Checks,
   in order: the swap is `Open` (`SwapNotOpen()`), `block.timestamp >= timelock`
   (`NotExpired()`). It sets the state to `Refunded` and pays the sender.
9. At any timestamp exactly one of claim and refund is possible: a claim is valid strictly
   before `timelock`, a refund from `timelock` onwards.

### Payments

10. State is updated before any ETH or token is sent. A failed ETH transfer reverts with
    `TransferFailed()`, leaving the swap `Open`.
11. A swap pays out exactly once and only its own stored amount; funds of other swaps held
    by the same contract are never touched.

## What the tests check

- Lock, claim and refund for ETH and tokens, including the timelock boundary.
- A complete two-chain swap in which the second claim uses the preimage published by the
  first, and the abort path in which both sides are refunded.
- Fee-on-transfer tokens, tokens that return nothing, tokens that return `false`.
- Re-entrant and ETH-rejecting recipients.
- Double claims, claim-then-refund, wrong preimages, id reuse and argument validation.
