// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract PullAuction {
    address public highestBidder;
    uint256 public highestBid;
    mapping(address => uint256) public pendingReturns;

    function bid() external payable {
        require(msg.value > highestBid, "BID_TOO_LOW");
        if (highestBidder != address(0)) {
            // VULNERABLE: Synchronous push fails if previous bidder reverts!
            (bool ok, ) = highestBidder.call{value: highestBid}("");
            require(ok, "REFUND_FAILED");
        }
        highestBidder = msg.sender;
        highestBid = msg.value;
    }

    function withdrawRefund() external {
        uint256 amt = pendingReturns[msg.sender];
        require(amt > 0, "NOTHING_TO_WITHDRAW");
        pendingReturns[msg.sender] = 0;
        (bool ok, ) = msg.sender.call{value: amt}("");
        require(ok, "WITHDRAW_FAILED");
    }
}