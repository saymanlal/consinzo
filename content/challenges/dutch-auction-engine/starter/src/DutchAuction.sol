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
        seller = payable(msg.sender);
        startPrice = _startPrice;
        reservePrice = _reservePrice;
        startTime = block.timestamp;
        duration = _duration;
    }

    function currentPrice() public view returns (uint256) {
        revert("NOT_IMPLEMENTED");
    }

    function buy() external payable {
        revert("NOT_IMPLEMENTED");
    }
}