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
        // TODO: Reject contributions at or after the deadline and zero-value contributions.
        // TODO: Record the contribution, grow totalRaised and emit Contributed.
        revert("NOT_IMPLEMENTED");
    }

    function claim() external {
        // TODO: Only the creator, only after the deadline, only if the goal was reached, only once.
        // TODO: Send totalRaised to the creator and emit Claimed.
        revert("NOT_IMPLEMENTED");
    }

    function refund() external {
        // TODO: Only after the deadline and only if the goal was missed.
        // TODO: Zero the caller's contribution before sending it back; emit Refunded.
        revert("NOT_IMPLEMENTED");
    }
}
