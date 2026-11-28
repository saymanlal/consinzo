# Crowdfunding Campaign with Goal and Deadline

## Problem Statement

Implement `Crowdfund` in `src/Crowdfund.sol`: an all-or-nothing fundraising campaign paid in ETH.

The deployer is the `creator`. Backers send ETH until the `deadline`. When the deadline has
passed, the campaign has one of two outcomes:

- **Success** (`totalRaised >= goal`): the creator can claim everything once.
- **Failure** (`totalRaised < goal`): each backer can take their own contribution back.

## Required Interface

```solidity
constructor(uint256 _goal, uint256 _duration)   // deadline = block.timestamp + _duration
function contribute() external payable
function claim() external
function refund() external

// public state (already declared in the starter)
address public immutable creator;
uint256 public immutable goal;
uint256 public immutable deadline;
uint256 public totalRaised;
bool public claimed;
mapping(address => uint256) public contributions;
```

## Rules

1. `contribute()`
   - reverts with `CampaignEnded()` when `block.timestamp >= deadline`;
   - reverts with `ZeroAmount()` when `msg.value == 0`;
   - otherwise adds `msg.value` to `contributions[msg.sender]` and to `totalRaised`, and emits
     `Contributed(msg.sender, msg.value)`. Contributions above the goal are accepted.
2. `claim()`
   - reverts with `NotCreator()` unless `msg.sender == creator`;
   - reverts with `CampaignActive()` when `block.timestamp < deadline`;
   - reverts with `GoalNotReached()` when `totalRaised < goal`;
   - reverts with `AlreadyClaimed()` on a second call;
   - otherwise sets `claimed = true`, sends `totalRaised` wei to the creator and emits
     `Claimed(totalRaised)`.
3. `refund()`
   - reverts with `CampaignActive()` when `block.timestamp < deadline`;
   - reverts with `GoalWasReached()` when `totalRaised >= goal`;
   - reverts with `NothingToRefund()` when the caller has no recorded contribution;
   - otherwise zeroes the caller's contribution, sends that amount back and emits
     `Refunded(msg.sender, amount)`. `totalRaised` is a historical total and is **not** reduced.
4. Any failed ETH transfer reverts with `TransferFailed()`.

The checks must be evaluated in the order listed.

## What the Tests Check

- Public tests: contributions are recorded, the creator claims a successful campaign, and backers
  refund a failed one.
- Hidden tests: the exact deadline boundary, each revert condition above, double claim and double
  refund, a campaign that lands exactly on the goal, and a backer contract that re-enters `refund`.
