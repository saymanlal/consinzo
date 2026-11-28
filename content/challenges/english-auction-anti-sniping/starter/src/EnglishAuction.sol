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
        // TODO: Reject bids once the auction has ended.
        // TODO: Enforce the reserve for the first bid and highestBid + minIncrement afterwards.
        // TODO: Credit the outbid amount to pendingReturns (no external call), record the new leader.
        // TODO: Extend endTime when fewer than extensionWindow seconds remain; emit BidPlaced.
        revert("NOT_IMPLEMENTED");
    }

    function withdraw() external {
        // TODO: Pay out the caller's pendingReturns, zeroing the balance before the transfer.
        revert("NOT_IMPLEMENTED");
    }

    function settle() external {
        // TODO: Only after endTime and only once. Pay highestBid to the seller if there was a bid; emit Settled.
        revert("NOT_IMPLEMENTED");
    }
}
