// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract MilestoneEscrow {
    address public immutable buyer;
    address public immutable seller;
    address public immutable arbiter;
    uint256 public amount;
    bool public settled;

    constructor(address _seller, address _arbiter) payable {
        buyer = msg.sender;
        seller = _seller;
        arbiter = _arbiter;
        amount = msg.value;
    }

    function approveRelease() external {
        revert("NOT_IMPLEMENTED");
    }

    function resolveDispute(bool paySeller) external {
        revert("NOT_IMPLEMENTED");
    }
}