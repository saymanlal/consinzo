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
        if (msg.sender != owner) revert NotOwner();
        if (chainId == 0 || capacity == 0 || breakerThreshold == 0 || breakerWindow == 0) revert InvalidConfig();

        Route storage r = _routes[chainId];
        if (r.configured) {
            // Settle the time that has passed under the old parameters first. Otherwise
            // the new rate would be applied retroactively to the whole idle period.
            uint128 current = _currentTokens(r);
            r.tokens = current > capacity ? capacity : current;
        } else {
            r.configured = true;
            r.tokens = capacity; // a new route starts with a full bucket
            r.windowStart = uint64(block.timestamp);
        }
        r.lastRefill = uint64(block.timestamp);
        r.capacity = capacity;
        r.refillPerSecond = refillPerSecond;
        r.breakerThreshold = breakerThreshold;
        r.breakerWindow = breakerWindow;
        emit RouteConfigured(chainId, capacity, refillPerSecond, breakerThreshold, breakerWindow);
    }

    function pause(uint256 chainId) external {
        if (msg.sender != owner && msg.sender != guardian) revert NotAuthorized();
        Route storage r = _route(chainId);
        r.paused = true;
        emit RoutePaused(chainId, msg.sender);
    }

    function unpause(uint256 chainId) external {
        if (msg.sender != owner) revert NotOwner();
        Route storage r = _route(chainId);
        if (!r.paused) revert NotPaused();
        r.paused = false;
        // Start a fresh window; the outflow that tripped the breaker has been reviewed.
        r.windowStart = uint64(block.timestamp);
        r.windowOutflow = 0;
        emit RouteUnpaused(chainId);
    }

    // ------------------------------------------------------------------ bridge

    /// @notice Ask to send `amount` out on `chainId`.
    /// @return allowed False when the route is paused, the bucket is too empty, or the
    ///         request trips the breaker. Limit conditions are reported by return value,
    ///         not by reverting: a revert would roll back the pause set by the breaker.
    function consume(uint256 chainId, uint256 amount) external returns (bool allowed) {
        if (msg.sender != bridge) revert NotBridge();
        Route storage r = _route(chainId);
        if (amount == 0) revert ZeroAmount();
        if (r.paused) return false;

        uint128 tokens = _currentTokens(r);
        if (amount > tokens) return false;

        // Roll the breaker window if the previous one is over.
        uint128 outflow = r.windowOutflow;
        if (block.timestamp >= uint256(r.windowStart) + r.breakerWindow) {
            r.windowStart = uint64(block.timestamp);
            outflow = 0;
        }

        // amount <= tokens <= type(uint128).max, so the sum fits in uint256.
        if (uint256(outflow) + amount > r.breakerThreshold) {
            r.paused = true;
            r.windowOutflow = outflow;
            emit BreakerTripped(chainId, outflow, amount);
            emit RoutePaused(chainId, address(this));
            return false;
        }

        r.tokens = tokens - uint128(amount);
        r.lastRefill = uint64(block.timestamp);
        r.windowOutflow = outflow + uint128(amount);
        emit Consumed(chainId, amount);
        return true;
    }

    /// @notice Credit inbound value back to the bucket, up to its capacity.
    ///         Does not reduce the outflow counted by the breaker.
    function replenish(uint256 chainId, uint256 amount) external {
        if (msg.sender != bridge) revert NotBridge();
        Route storage r = _route(chainId);
        uint256 total = uint256(_currentTokens(r)) + amount;
        // `amount` is unbounded; compare in uint256 before narrowing.
        r.tokens = total > r.capacity ? r.capacity : uint128(total);
        r.lastRefill = uint64(block.timestamp);
        emit Replenished(chainId, amount);
    }

    // ------------------------------------------------------------------- views

    function getRoute(uint256 chainId) external view returns (Route memory) {
        return _routes[chainId];
    }

    function isPaused(uint256 chainId) external view returns (bool) {
        return _routes[chainId].paused;
    }

    /// @notice Bucket content right now (0 for unknown routes). Ignores the pause flag.
    function available(uint256 chainId) external view returns (uint256) {
        return _currentTokens(_routes[chainId]);
    }

    /// @notice Outflow counted in the current window; 0 once that window has ended.
    function windowOutflow(uint256 chainId) external view returns (uint256) {
        Route storage r = _routes[chainId];
        if (block.timestamp >= uint256(r.windowStart) + r.breakerWindow) return 0;
        return r.windowOutflow;
    }

    // ---------------------------------------------------------------- internal

    function _route(uint256 chainId) internal view returns (Route storage r) {
        r = _routes[chainId];
        if (!r.configured) revert RouteNotConfigured();
    }

    /// @dev tokens + elapsed * rate, capped at capacity. Computed in uint256: elapsed fits
    ///      in 64 bits and the rate in 128, so the product cannot overflow.
    function _currentTokens(Route storage r) internal view returns (uint128) {
        uint256 elapsed = block.timestamp - r.lastRefill;
        uint256 refilled = uint256(r.tokens) + elapsed * uint256(r.refillPerSecond);
        uint256 cap = r.capacity;
        return uint128(refilled > cap ? cap : refilled);
    }
}
