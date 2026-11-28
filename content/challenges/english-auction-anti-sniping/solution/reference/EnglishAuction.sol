// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title Ascending ETH auction with pull-based refunds and a soft close.
contract EnglishAuction {
    address public immutable seller;
    uint256 public immutable reservePrice;
    uint256 public immutable minIncrement;
    uint256 public immutable extensionWindow;

    uint256 public endTime;
    address public highestBidder;
    uint256 public highestBid;
    bool public settled;
    mapping(address => uint256) public pendingReturns;

    event BidPlaced(address indexed bidder, uint256 amount, uint256 endTime);
    event Withdrawn(address indexed bidder, uint256 amount);
    event Settled(address indexed winner, uint256 amount);

    error AuctionEnded();
    error AuctionNotEnded();
    error AlreadySettled();
    error BidTooLow();
    error NothingToWithdraw();
    error TransferFailed();

    constructor(uint256 _reservePrice, uint256 _minIncrement, uint256 _duration, uint256 _extensionWindow) {
        seller = msg.sender;
        reservePrice = _reservePrice;
        minIncrement = _minIncrement;
        extensionWindow = _extensionWindow;
        endTime = block.timestamp + _duration;
    }

    function bid() external payable {
        if (block.timestamp >= endTime) revert AuctionEnded();

        address previousBidder = highestBidder;
        uint256 minimum = previousBidder == address(0) ? reservePrice : highestBid + minIncrement;
        if (msg.value < minimum) revert BidTooLow();

        // Pull pattern: the outbid bidder is credited, never called.
        if (previousBidder != address(0)) {
            pendingReturns[previousBidder] += highestBid;
        }
        highestBidder = msg.sender;
        highestBid = msg.value;

        // Soft close: a late bid always leaves a full extension window for a response.
        if (endTime - block.timestamp < extensionWindow) {
            endTime = block.timestamp + extensionWindow;
        }
        emit BidPlaced(msg.sender, msg.value, endTime);
    }

    function withdraw() external {
        uint256 amount = pendingReturns[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        pendingReturns[msg.sender] = 0;
        emit Withdrawn(msg.sender, amount);

        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    function settle() external {
        if (block.timestamp < endTime) revert AuctionNotEnded();
        if (settled) revert AlreadySettled();

        settled = true;
        emit Settled(highestBidder, highestBid);

        if (highestBidder != address(0)) {
            (bool ok, ) = seller.call{value: highestBid}("");
            if (!ok) revert TransferFailed();
        }
    }
}
