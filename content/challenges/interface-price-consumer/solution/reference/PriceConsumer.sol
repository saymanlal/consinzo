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

    uint256 private _price;
    uint8 private immutable _decimals;

    error NotOwner();
    error ZeroPrice();

    constructor(uint256 initialPrice, uint8 decimals_) {
        if (initialPrice == 0) revert ZeroPrice();
        owner = msg.sender;
        _price = initialPrice;
        _decimals = decimals_;
    }

    function latestPrice() external view returns (uint256) {
        return _price;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function setPrice(uint256 newPrice) external {
        if (msg.sender != owner) revert NotOwner();
        if (newPrice == 0) revert ZeroPrice();
        _price = newPrice;
    }
}

contract PriceConsumer {
    // The consumer only knows the interface. Any conforming provider can be plugged in.
    IPriceFeed public immutable feed;

    error ZeroFeed();

    constructor(IPriceFeed feed_) {
        if (address(feed_) == address(0)) revert ZeroFeed();
        feed = feed_;
    }

    function currentPrice() external view returns (uint256) {
        return feed.latestPrice();
    }

    function quote(uint256 amount) external view returns (uint256) {
        // Both values are read on every call; nothing is cached in this contract.
        return (amount * feed.latestPrice()) / (10 ** uint256(feed.decimals()));
    }

    function isAtLeast(uint256 threshold) external view returns (bool) {
        return feed.latestPrice() >= threshold;
    }
}
