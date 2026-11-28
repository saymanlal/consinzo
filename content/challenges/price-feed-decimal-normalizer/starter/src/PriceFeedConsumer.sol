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
    IAggregatorV3 public immutable feed;
    uint256 public immutable maxAge;

    error ZeroAddress();
    error InvalidPrice();
    error StalePrice();

    constructor(address feed_, uint256 maxAge_) {
        // TODO: revert with ZeroAddress() when feed_ is the zero address
        feed = IAggregatorV3(feed_);
        maxAge = maxAge_;
    }

    /// @notice Latest answer of the feed as an unsigned 18-decimal fixed-point number.
    function latestPrice() public view returns (uint256 price18) {
        // TODO: read latestRoundData(), reject answer <= 0 with InvalidPrice()
        // TODO: reject updatedAt == 0, a future updatedAt, or an age above maxAge with StalePrice()
        // TODO: scale the answer from feed.decimals() to 18 decimals (up or down)
        revert("NOT_IMPLEMENTED");
    }

    /// @notice Value of `baseAmount` (with `baseDecimals` decimals) in the quote currency, 18 decimals.
    function toQuote(uint256 baseAmount, uint8 baseDecimals) external view returns (uint256 quote18) {
        // TODO: baseAmount * latestPrice() / 10 ** baseDecimals
        revert("NOT_IMPLEMENTED");
    }
}
