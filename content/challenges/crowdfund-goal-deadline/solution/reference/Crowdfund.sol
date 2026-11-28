// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title All-or-nothing ETH crowdfunding campaign.
contract Crowdfund {
    address public immutable creator;
    uint256 public immutable goal;
    uint256 public immutable deadline;

    uint256 public totalRaised;
    bool public claimed;
    mapping(address => uint256) public contributions;

    event Contributed(address indexed backer, uint256 amount);
    event Claimed(uint256 amount);
    event Refunded(address indexed backer, uint256 amount);

    error ZeroAmount();
    error CampaignEnded();
    error CampaignActive();
    error NotCreator();
    error GoalNotReached();
    error GoalWasReached();
    error AlreadyClaimed();
    error NothingToRefund();
    error TransferFailed();

    constructor(uint256 _goal, uint256 _duration) {
        creator = msg.sender;
        goal = _goal;
        deadline = block.timestamp + _duration;
    }

    function contribute() external payable {
        if (block.timestamp >= deadline) revert CampaignEnded();
        if (msg.value == 0) revert ZeroAmount();

        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;
        emit Contributed(msg.sender, msg.value);
    }

    function claim() external {
        if (msg.sender != creator) revert NotCreator();
        if (block.timestamp < deadline) revert CampaignActive();
        if (totalRaised < goal) revert GoalNotReached();
        if (claimed) revert AlreadyClaimed();

        // Effects before the external call.
        claimed = true;
        uint256 amount = totalRaised;
        emit Claimed(amount);

        (bool ok, ) = creator.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    function refund() external {
        if (block.timestamp < deadline) revert CampaignActive();
        if (totalRaised >= goal) revert GoalWasReached();

        uint256 amount = contributions[msg.sender];
        if (amount == 0) revert NothingToRefund();

        // Zero the balance first so a re-entrant call has nothing left to take.
        contributions[msg.sender] = 0;
        emit Refunded(msg.sender, amount);

        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}
