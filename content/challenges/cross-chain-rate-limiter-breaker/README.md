# Cross-Chain Rate Limiter with Circuit Breaker

## Problem Statement

When a bridge is exploited, the damage is usually bounded only by how much it holds.
Two cheap defences change that:

- a **token bucket** per route, which bounds how fast value can leave towards one chain;
- a **circuit breaker**, which pauses a route outright when the outflow in a time window
  is abnormal, and keeps it paused until a human looks at it.

Implement `RouteRateLimiter` in `src/RouteRateLimiter.sol`. It holds no funds. A bridge
contract (the `bridge` address) calls `consume` before each outbound transfer and
`replenish` on each inbound one, and acts on the result.

## Interface

```solidity
struct Route {
    bool configured;
    bool paused;
    uint64 lastRefill;
    uint64 windowStart;
    uint64 breakerWindow;
    uint128 capacity;
    uint128 refillPerSecond;
    uint128 tokens;
    uint128 breakerThreshold;
    uint128 windowOutflow;
}

constructor(address bridge_, address guardian_)      // owner = msg.sender

function owner() external view returns (address);
function bridge() external view returns (address);
function guardian() external view returns (address);

function configureRoute(uint256 chainId, uint128 capacity, uint128 refillPerSecond,
                        uint128 breakerThreshold, uint64 breakerWindow) external;   // owner
function pause(uint256 chainId) external;                                           // owner or guardian
function unpause(uint256 chainId) external;                                         // owner

function consume(uint256 chainId, uint256 amount) external returns (bool allowed);  // bridge
function replenish(uint256 chainId, uint256 amount) external;                       // bridge

function getRoute(uint256 chainId) external view returns (Route memory);
function isPaused(uint256 chainId) external view returns (bool);
function available(uint256 chainId) external view returns (uint256);
function windowOutflow(uint256 chainId) external view returns (uint256);
```

Errors: `InvalidConfig`, `NotOwner`, `NotBridge`, `NotAuthorized`, `RouteNotConfigured`,
`ZeroAmount`, `NotPaused`.

## Rules

### Token bucket

1. A route's bucket holds at most `capacity` units and gains `refillPerSecond` units per
   second of block time, never exceeding `capacity`. `available(chainId)` returns the
   content at the current timestamp; it is `0` for an unconfigured route and is not
   affected by the pause flag.
2. Time keeps refilling the bucket while a route is paused.

### Configuration

3. The constructor reverts with `InvalidConfig()` if `bridge_` is the zero address. The
   guardian may be zero (no guardian).
4. `configureRoute` is owner-only (`NotOwner()`), then reverts with `InvalidConfig()` if
   `chainId`, `capacity`, `breakerThreshold` or `breakerWindow` is zero.
   `refillPerSecond` may be zero.
5. Configuring a **new** route: the bucket starts full and the breaker window starts at
   the current timestamp with zero outflow.
6. Re-configuring an **existing** route: the bucket is first brought up to date using the
   **old** capacity and rate, then the new parameters are stored and the content is capped
   at the new capacity. The pause flag and the breaker window (start and recorded outflow)
   are kept. The new window length and threshold apply to the window in progress.

### Consuming

7. `consume` reverts only for `NotBridge()`, `RouteNotConfigured()` and `ZeroAmount()`,
   checked in that order. Every limit condition is reported by returning `false`.
8. It returns `false`, changing nothing, if the route is paused.
9. Otherwise it returns `false`, without recording outflow, if `amount` exceeds the
   bucket content.
10. Otherwise the breaker is evaluated. A window covers the timestamps
    `[windowStart, windowStart + breakerWindow)`. If the current timestamp is outside the
    window, a new window starts now with zero outflow. Then, if
    `windowOutflow + amount > breakerThreshold`, the breaker **trips**: the route becomes
    paused, the amount is not taken from the bucket and not added to the outflow, and
    `consume` returns `false`. The pause must persist after the call.
11. Otherwise `amount` leaves the bucket, is added to the window's outflow, and `consume`
    returns `true`. Outflow exactly equal to the threshold is allowed.
12. `windowOutflow(chainId)` returns the outflow recorded in the current window, or `0` if
    that window has ended.

### Replenishing

13. `replenish` reverts for `NotBridge()` then `RouteNotConfigured()`. It adds `amount` to
    the bucket, capped at capacity, for any `amount` up to `type(uint256).max`. It works on
    paused routes. It never reduces the outflow counted by the breaker: the breaker
    measures gross outflow.

### Pausing

14. `pause` may be called by the owner or the guardian (`NotAuthorized()` otherwise) on a
    configured route (`RouteNotConfigured()`). Pausing a paused route is a no-op.
15. `unpause` is owner-only (`NotOwner()`), requires a configured route
    (`RouteNotConfigured()`) that is paused (`NotPaused()`). It clears the flag and starts
    a new breaker window at the current timestamp with zero outflow.

Routes are independent of each other in every respect.

## Why `consume` returns a boolean

If `consume` reverted when the breaker trips, the transaction would roll back and the
pause flag with it. The attacker could simply try again with a slightly smaller amount.
The limiter therefore records the trip and returns `false`; the bridge is expected to
handle `false` without reverting the whole transaction (for example by queueing the
transfer).

## What the tests check

Refill arithmetic and capping, the exact threshold boundary, persistence of a trip, window
roll-over timing, splitting and ping-pong patterns, re-configuration in the middle of an
idle period, behaviour while paused, extreme parameter values, route independence and
access control.
