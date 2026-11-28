// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Chainlink-style aggregator interface.
interface IAggregatorV3 {
    function decimals() external view returns (uint8);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

/// @notice Values collateral in USD (18 decimals) for a lending market.
contract CollateralValuer {
    error UnsupportedDecimals();
    error InvalidBounds();
    error IncompleteRound();
    error StaleRound();
    error StalePrice();
    error InvalidPrice();
    error PriceOutOfBounds();

    uint256 public constant BORROW_FACTOR_BPS = 7_500;

    IAggregatorV3 public immutable feed;
    /// @notice Maximum accepted age of a price, in seconds.
    uint256 public immutable maxStaleness;
    /// @notice The feed's circuit-breaker limits. Answers at or beyond them are clamped values.
    int256 public immutable minAnswer;
    int256 public immutable maxAnswer;
    uint256 private immutable _scale;

    constructor(IAggregatorV3 _feed, uint256 _maxStaleness, int256 _minAnswer, int256 _maxAnswer) {
        uint8 d = _feed.decimals();
        if (d > 18) revert UnsupportedDecimals();
        if (_minAnswer <= 0 || _maxAnswer <= _minAnswer) revert InvalidBounds();
        feed = _feed;
        maxStaleness = _maxStaleness;
        minAnswer = _minAnswer;
        maxAnswer = _maxAnswer;
        _scale = 10 ** (18 - d);
    }

    /// @notice Latest validated price, scaled to 18 decimals.
    function latestPrice() public view returns (uint256) {
        (uint80 roundId, int256 answer, , uint256 updatedAt, uint80 answeredInRound) = feed.latestRoundData();

        // A round that has not been answered yet reports updatedAt == 0. A timestamp from
        // the future is equally unusable (and would underflow the age computation).
        if (updatedAt == 0 || updatedAt > block.timestamp) revert IncompleteRound();
        // The answer was computed in an earlier round and merely carried forward.
        if (answeredInRound < roundId) revert StaleRound();
        // Heartbeat check: exactly maxStaleness seconds old is still accepted.
        if (block.timestamp - updatedAt > maxStaleness) revert StalePrice();
        // Sign check on the signed value; uint256(negative) would be astronomically large.
        if (answer <= 0) revert InvalidPrice();
        // At the circuit-breaker limits the feed reports the limit, not the market price.
        if (answer <= minAnswer || answer >= maxAnswer) revert PriceOutOfBounds();

        return uint256(answer) * _scale;
    }

    /// @notice USD value (18 decimals) of `amount` collateral tokens (18 decimals).
    function valueOf(uint256 amount) public view returns (uint256) {
        return (amount * latestPrice()) / 1e18;
    }

    /// @notice USD amount that may be borrowed against `amount` collateral tokens.
    function maxBorrow(uint256 amount) external view returns (uint256) {
        return (valueOf(amount) * BORROW_FACTOR_BPS) / 10_000;
    }
}
