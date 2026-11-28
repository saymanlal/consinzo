// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Subset of the Chainlink AggregatorV3 interface used by the consumer.
interface IAggregatorV3 {
    function decimals() external view returns (uint8);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

contract PriceFeedConsumer {
    uint8 internal constant TARGET_DECIMALS = 18;

    IAggregatorV3 public immutable feed;
    uint256 public immutable maxAge;

    error ZeroAddress();
    error InvalidPrice();
    error StalePrice();

    constructor(address feed_, uint256 maxAge_) {
        if (feed_ == address(0)) revert ZeroAddress();
        feed = IAggregatorV3(feed_);
        maxAge = maxAge_;
    }

    /// @notice Latest answer of the feed as an unsigned 18-decimal fixed-point number.
    function latestPrice() public view returns (uint256 price18) {
        (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();

        // A signed answer must be validated before the cast: a negative int256 cast to
        // uint256 becomes an enormous positive price.
        if (answer <= 0) revert InvalidPrice();

        // updatedAt == 0 means the round never completed. The future check also keeps the
        // subtraction below from underflowing into a Panic instead of a typed error.
        if (updatedAt == 0 || updatedAt > block.timestamp) revert StalePrice();
        if (block.timestamp - updatedAt > maxAge) revert StalePrice();

        uint8 feedDecimals = feed.decimals();
        uint256 raw = uint256(answer);
        if (feedDecimals < TARGET_DECIMALS) {
            price18 = raw * 10 ** uint256(TARGET_DECIMALS - feedDecimals);
        } else if (feedDecimals > TARGET_DECIMALS) {
            price18 = raw / 10 ** uint256(feedDecimals - TARGET_DECIMALS);
        } else {
            price18 = raw;
        }
    }

    /// @notice Value of `baseAmount` (with `baseDecimals` decimals) in the quote currency, 18 decimals.
    function toQuote(uint256 baseAmount, uint8 baseDecimals) external view returns (uint256 quote18) {
        // Multiply before dividing so small amounts do not lose precision.
        quote18 = (baseAmount * latestPrice()) / 10 ** uint256(baseDecimals);
    }
}
