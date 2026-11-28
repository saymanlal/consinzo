# Member Poll with Quorum and Passing Threshold

## Problem Statement

Implement `MemberPoll` in `src/MemberPoll.sol`: one-member-one-vote polls for a fixed membership.

The member list, the quorum and the passing threshold are fixed at deployment (the constructor is
provided). Any member can open a poll with a deadline. Members vote yes or no once per poll.
After the deadline the poll has a final outcome that anyone can read.

## Required Interface

```solidity
enum Outcome { Pending, Passed, Rejected, QuorumNotMet }

constructor(address[] memory members, uint256 _quorum, uint256 _thresholdBps)   // provided

function createPoll(bytes32 topic, uint256 duration) external returns (uint256 pollId)
function vote(uint256 pollId, bool support) external
function getPoll(uint256 pollId) external view
    returns (bytes32 topic, uint256 deadline, uint256 yesVotes, uint256 noVotes)
function outcome(uint256 pollId) external view returns (Outcome)

// public state (already declared in the starter)
mapping(address => bool) public isMember;
uint256 public memberCount;
uint256 public immutable quorum;         // minimum number of votes cast (yes + no)
uint256 public immutable thresholdBps;   // minimum yes share of the votes cast, in basis points
uint256 public pollCount;
mapping(uint256 => mapping(address => bool)) public hasVoted;
```

## Rules

1. `createPoll(topic, duration)`
   - reverts with `NotMember()` if the caller is not a member;
   - reverts with `InvalidDuration()` if `duration == 0`;
   - poll ids start at `0` and increase by one; the function returns the new id and increments
     `pollCount`; the poll's `deadline` is `block.timestamp + duration`;
   - emits `PollCreated(pollId, topic, deadline)`.
2. `vote(pollId, support)`
   - reverts with `NotMember()` if the caller is not a member;
   - reverts with `UnknownPoll()` if `pollId >= pollCount`;
   - reverts with `VotingClosed()` if `block.timestamp >= deadline`;
   - reverts with `AlreadyVoted()` if the caller already voted in this poll;
   - otherwise records the vote, counts it as yes or no, and emits
     `VoteCast(pollId, voter, support)`. A vote cannot be changed.
3. `getPoll(pollId)` and `outcome(pollId)` revert with `UnknownPoll()` for an id that does not
   exist.
4. `outcome(pollId)`
   - `Pending` while `block.timestamp < deadline`, whatever the current counts are;
   - otherwise `QuorumNotMet` if `yesVotes + noVotes < quorum`;
   - otherwise `Passed` if `yesVotes * 10000 >= thresholdBps * (yesVotes + noVotes)`;
   - otherwise `Rejected`.

The checks must be evaluated in the order listed.

## What the Tests Check

- Public tests: poll creation, vote counting, and each of the three final outcomes.
- Hidden tests: non-members, double voting, unknown polls, the deadline boundary, quorum exactly
  met and missed by one, the threshold exactly met and missed by one vote, a supermajority
  threshold, and independence of several concurrent polls.
