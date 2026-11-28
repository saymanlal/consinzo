// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IPriceFeed {
    /// Latest price, scaled by 10 ** decimals().
    function latestPrice() external view returns (uint256);

    /// Number of decimals used by latestPrice().
    function decimals() external view returns (uint8);
}

contract FixedPriceFeed is IPriceFeed {
    address public immutable owner;

    error NotOwner();
    error ZeroPrice();

    constructor(uint256 initialPrice, uint8 decimals_) {
        // TODO: reject a zero price, record the owner, the price and the decimals
        owner = msg.sender;
    }

    function latestPrice() external view returns (uint256) {
        // TODO: return the most recently set price
        revert("NOT_IMPLEMENTED");
    }

    function decimals() external view returns (uint8) {
        // TODO: return the decimals given at construction
        revert("NOT_IMPLEMENTED");
    }

    function setPrice(uint256 newPrice) external {
        // TODO: only the owner; reject a zero price; store the new price
        revert("NOT_IMPLEMENTED");
    }
}

contract PriceConsumer {
    IPriceFeed public immutable feed;

    error ZeroFeed();

    constructor(IPriceFeed feed_) {
        // TODO: reject the zero address, then store the feed
    }

    function currentPrice() external view returns (uint256) {
        // TODO: read the price from the feed
        revert("NOT_IMPLEMENTED");
    }

    function quote(uint256 amount) external view returns (uint256) {
        // TODO: amount * price / 10 ** decimals, using the feed's current values
        revert("NOT_IMPLEMENTED");
    }

    function isAtLeast(uint256 threshold) external view returns (bool) {
        // TODO: compare the feed's current price with the threshold
        revert("NOT_IMPLEMENTED");
    }
}
