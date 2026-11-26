// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract MilestoneEscrow {
    address public immutable buyer;
    address public immutable seller;
    address public immutable arbiter;
    uint256 public amount;
    bool public settled;

    constructor(address _seller, address _arbiter) payable {
        require(_seller != address(0) && _arbiter != address(0) && msg.value > 0, "INVALID_INIT");
        buyer = msg.sender;
        seller = _seller;
        arbiter = _arbiter;
        amount = msg.value;
    }

    function approveRelease() external {
        require(msg.sender == buyer, "ONLY_BUYER");
        require(!settled, "ALREADY_SETTLED");
        settled = true;
        (bool ok, ) = seller.call{value: amount}("");
        require(ok, "PAY_FAILED");
    }

    function resolveDispute(bool paySeller) external {
        require(msg.sender == arbiter, "ONLY_ARBITER");
        require(!settled, "ALREADY_SETTLED");
        settled = true;
        address recipient = paySeller ? seller : buyer;
        (bool ok, ) = recipient.call{value: amount}("");
        require(ok, "PAY_FAILED");
    }
}