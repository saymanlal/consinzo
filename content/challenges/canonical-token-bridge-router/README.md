# Canonical Token Registry and Bridge Router

## Problem Statement

A lock-and-release bridge that serves several destination chains has to answer two
questions for every transfer: *which token on the other chain is the canonical counterpart
of this one*, and *whose money is paying for this release*. If all routes share one pool, a
fault on one remote chain can drain liquidity that backs tokens on another.

Implement `CanonicalBridgeRouter` in `src/CanonicalBridgeRouter.sol`. It keeps a registry of
`(local token, destination chain) -> remote token` routes, charges a per-route fee on
outbound transfers, and keeps a separate liquidity book and fee book for every route.

Remote chains are not simulated. Outbound transfers only lock tokens and emit an event;
inbound transfers are delivered by a trusted `relayer` address.

## Interface

```solidity
uint256 public constant MAX_FEE_BPS = 1_000;

constructor(address relayer_)                      // owner = msg.sender

function owner() external view returns (address);
function relayer() external view returns (address);
function setRelayer(address relayer_) external;                                   // owner

function registerRoute(address token, uint256 chainId, bytes32 remoteToken, uint256 feeBps) external; // owner
function setRouteFee(address token, uint256 chainId, uint256 feeBps) external;    // owner
function routeOf(address token, uint256 chainId) external view returns (bytes32 remoteToken, uint256 feeBps);
function localTokenOf(uint256 chainId, bytes32 remoteToken) external view returns (address);
function quote(address token, uint256 chainId, uint256 amount) external view returns (uint256 netAmount, uint256 fee);

function bridgeOut(address token, uint256 chainId, uint256 amount, bytes32 recipient) external returns (uint256 nonce);
function bridgeIn(uint256 chainId, bytes32 remoteToken, address recipient, uint256 amount, uint256 nonce) external; // relayer

function lockedLiquidity(address token, uint256 chainId) external view returns (uint256);
function accruedFees(address token, uint256 chainId) external view returns (uint256);
function outboundNonce(uint256 chainId) external view returns (uint256);
function inboundProcessed(uint256 chainId, uint256 nonce) external view returns (bool);
function withdrawFees(address token, uint256 chainId, address to) external returns (uint256 amount); // owner
```

Errors: `NotOwner`, `NotRelayer`, `ZeroAddress`, `ZeroAmount`, `InvalidChain`,
`InvalidRemoteToken`, `RouteExists`, `RemoteTokenTaken`, `RouteNotFound`, `FeeTooHigh`,
`AlreadyProcessed`, `InsufficientRouteLiquidity`, `TransferFailed`. Events are declared in
the starter.

## Rules

### Registry

1. Owner-only functions revert with `NotOwner()` for anyone else; this check comes first.
2. `registerRoute` checks, in this order: `token == address(0)` -> `ZeroAddress()`;
   `chainId == 0` or `chainId == block.chainid` -> `InvalidChain()`; `remoteToken == 0` ->
   `InvalidRemoteToken()`; `feeBps > MAX_FEE_BPS` -> `FeeTooHigh()`; the route
   `(token, chainId)` already exists -> `RouteExists()`; `remoteToken` is already mapped to
   a local token on `chainId` -> `RemoteTokenTaken()`.
3. The same `remoteToken` value may be used on different chains, and one local token may
   have routes to many chains. Routes cannot be removed or re-pointed.
4. `setRouteFee` reverts with `RouteNotFound()` for an unknown route, then `FeeTooHigh()`.
   A new fee applies to later transfers only.
5. `routeOf` returns `(0, 0)` for an unknown route. `quote` reverts with `RouteNotFound()`
   for an unknown route; otherwise `fee = amount * feeBps / 10_000` rounded down and
   `netAmount = amount - fee`.

### Outbound

6. `bridgeOut` checks, in this order: route exists (`RouteNotFound()`), `amount != 0`
   (`ZeroAmount()`), `recipient != 0` (`ZeroAddress()`).
7. It pulls `amount` with `transferFrom` (a `false` return is `TransferFailed()`) and books
   the amount that **actually arrived**, measured as the router's balance difference. If
   nothing arrived it reverts with `ZeroAmount()`.
8. `fee = received * feeBps / 10_000` rounded down. `accruedFees[token][chainId]` grows by
   `fee`, `lockedLiquidity[token][chainId]` grows by `received - fee`.
9. `outboundNonce[chainId]` is incremented and returned; the first transfer to a chain has
   nonce 1. Nonces are per destination chain, shared by all tokens.

### Inbound

10. `bridgeIn` checks, in this order: caller is the relayer (`NotRelayer()`); the remote
    token resolves to a local token (`RouteNotFound()`); `recipient != address(0)`
    (`ZeroAddress()`); `amount != 0` (`ZeroAmount()`); `(chainId, nonce)` has not been
    processed (`AlreadyProcessed()`); `amount <= lockedLiquidity[token][chainId]`
    (`InsufficientRouteLiquidity()`).
11. It marks `(chainId, nonce)` processed, reduces the route's locked liquidity and
    transfers `amount` to `recipient` with no fee. Inbound nonces are per source chain and
    may arrive in any order.
12. An inbound transfer is paid only from the liquidity locked towards the same chain for
    the same token. Accrued fees and other routes' liquidity are never used.

### Fees

13. `withdrawFees` checks `to != address(0)` (`ZeroAddress()`), reverts with `ZeroAmount()`
    when the route has no accrued fees, otherwise zeroes the route's fee book and transfers
    exactly that amount.

At all times, for every token: router balance >= sum of `lockedLiquidity` + sum of
`accruedFees` over its routes.

## What the tests check

Registry validation and uniqueness, fee arithmetic and rounding, per-chain nonces, replay
protection, isolation between routes, fee withdrawal that cannot touch locked liquidity,
access control, and correct accounting with a token that charges a fee on transfer.
