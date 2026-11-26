// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract DutchAuction {
    address payable public immutable seller;
    uint256 public immutable startPrice;
    uint256 public immutable reservePrice;
    uint256 public immutable startTime;
    uint256 public immutable duration;
    bool public sold;

    constructor(uint256 _startPrice, uint256 _reservePrice, uint256 _duration) {
        require(_startPrice >= _reservePrice && _duration > 0, "INVALID_AUCTION");
        seller = payable(msg.sender);
        startPrice = _startPrice;
        reservePrice = _reservePrice;
        startTime = block.timestamp;
        duration = _duration;
    }

    function currentPrice() public view returns (uint256) {
        uint256 elapsed = block.timestamp - startTime;
        if (elapsed >= duration) return reservePrice;
        uint256 discount = ((startPrice - reservePrice) * elapsed) / duration;
        return startPrice - discount;
    }

    function buy() external payable {
        require(!sold, "ALREADY_SOLD");
        uint256 price = currentPrice();
        require(msg.value >= price, "INSUFFICIENT_PAYMENT");
        sold = true;
        (bool okSeller, ) = seller.call{value: price}("");
        require(okSeller, "SELLER_PAY_FAILED");
        uint256 refund = msg.value - price;
        if (refund > 0) {
            (bool okBuyer, ) = msg.sender.call{value: refund}("");
            require(okBuyer, "REFUND_FAILED");
        }
    }
}