// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Outflow guard for a bridge. Every destination chain ("route") has
///         - a token bucket that bounds the short-term rate of outflow, and
///         - a circuit breaker that pauses the route when the outflow accumulated in a
///           time window exceeds a threshold.
///         The bridge asks `consume` before sending value out and acts on the answer.
contract RouteRateLimiter {
    struct Route {
        bool configured;
        bool paused;
        uint64 lastRefill; // timestamp the bucket was last brought up to date
        uint64 windowStart; // start of the current breaker window
        uint64 breakerWindow; // window length in seconds
        uint128 capacity; // bucket size
        uint128 refillPerSecond;
        uint128 tokens; // bucket content at lastRefill
        uint128 breakerThreshold; // max outflow per window
        uint128 windowOutflow; // outflow recorded in the current window
    }

    address public immutable owner;
    address public immutable bridge;
    address public immutable guardian;

    mapping(uint256 => Route) internal _routes;

    event RouteConfigured(
        uint256 indexed chainId, uint256 capacity, uint256 refillPerSecond, uint256 breakerThreshold, uint256 breakerWindow
    );
    event Consumed(uint256 indexed chainId, uint256 amount);
    event Replenished(uint256 indexed chainId, uint256 amount);
    event BreakerTripped(uint256 indexed chainId, uint256 windowOutflow, uint256 attempted);
    event RoutePaused(uint256 indexed chainId, address indexed by);
    event RouteUnpaused(uint256 indexed chainId);

    error InvalidConfig();
    error NotOwner();
    error NotBridge();
    error NotAuthorized();
    error RouteNotConfigured();
    error ZeroAmount();
    error NotPaused();

    constructor(address bridge_, address guardian_) {
        if (bridge_ == address(0)) revert InvalidConfig();
        owner = msg.sender;
        bridge = bridge_;
        guardian = guardian_;
    }

    // ------------------------------------------------------------------- admin

    function configureRoute(
        uint256 chainId,
        uint128 capacity,
        uint128 refillPerSecond,
        uint128 breakerThreshold,
        uint64 breakerWindow
    ) external {
        // TODO: owner only; validate the parameters
        // TODO: new route: full bucket, breaker window starts now
        // TODO: existing route: settle the refill under the OLD parameters, then cap at the new capacity
        revert("NOT_IMPLEMENTED");
    }

    function pause(uint256 chainId) external {
        // TODO: owner or guardian; route must exist
        revert("NOT_IMPLEMENTED");
    }

    function unpause(uint256 chainId) external {
        // TODO: owner only; route must be paused; start a fresh breaker window
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------------ bridge

    /// @notice Ask to send `amount` out on `chainId`.
    /// @return allowed False when the route is paused, the bucket is too empty, or the
    ///         request trips the breaker. Limit conditions are reported by return value,
    ///         not by reverting: a revert would roll back the pause set by the breaker.
    function consume(uint256 chainId, uint256 amount) external returns (bool allowed) {
        // TODO: bridge only; route must exist; amount non-zero
        // TODO: return false when paused or when the bucket holds less than amount
        // TODO: roll the breaker window if it has ended
        // TODO: if the request would push the window outflow above the threshold: pause the route and return false
        // TODO: otherwise take the tokens, record the outflow and return true
        revert("NOT_IMPLEMENTED");
    }

    /// @notice Credit inbound value back to the bucket, up to its capacity.
    ///         Does not reduce the outflow counted by the breaker.
    function replenish(uint256 chainId, uint256 amount) external {
        // TODO: bridge only; add to the bucket, capped at capacity
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------------- views

    function getRoute(uint256 chainId) external view returns (Route memory) {
        // TODO: return the stored route
        revert("NOT_IMPLEMENTED");
    }

    function isPaused(uint256 chainId) external view returns (bool) {
        // TODO: return the pause flag
        revert("NOT_IMPLEMENTED");
    }

    /// @notice Bucket content right now (0 for unknown routes). Ignores the pause flag.
    function available(uint256 chainId) external view returns (uint256) {
        // TODO: bucket content now: stored tokens plus refill since lastRefill, capped at capacity
        revert("NOT_IMPLEMENTED");
    }

    /// @notice Outflow counted in the current window; 0 once that window has ended.
    function windowOutflow(uint256 chainId) external view returns (uint256) {
        // TODO: outflow of the current window, 0 if that window has ended
        revert("NOT_IMPLEMENTED");
    }

    // ---------------------------------------------------------------- internal

    function _route(uint256 chainId) internal view returns (Route storage r) {
        // TODO: load the route or revert with RouteNotConfigured()
        revert("NOT_IMPLEMENTED");
    }

    /// @dev tokens + elapsed * rate, capped at capacity. Computed in uint256: elapsed fits
    ///      in 64 bits and the rate in 128, so the product cannot overflow.
    function _currentTokens(Route storage r) internal view returns (uint128) {
        // TODO: tokens + elapsed * refillPerSecond, capped at capacity, without overflow
        revert("NOT_IMPLEMENTED");
    }
}
