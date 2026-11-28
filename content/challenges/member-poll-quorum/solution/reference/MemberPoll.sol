// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title One-member-one-vote polls with a quorum and a yes-share threshold.
contract MemberPoll {
    enum Outcome {
        Pending,
        Passed,
        Rejected,
        QuorumNotMet
    }

    struct Poll {
        bytes32 topic;
        uint256 deadline;
        uint256 yesVotes;
        uint256 noVotes;
    }

    uint256 private constant BPS = 10_000;

    mapping(address => bool) public isMember;
    uint256 public memberCount;
    uint256 public immutable quorum;
    uint256 public immutable thresholdBps;

    uint256 public pollCount;
    mapping(uint256 => Poll) private polls;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event PollCreated(uint256 indexed pollId, bytes32 topic, uint256 deadline);
    event VoteCast(uint256 indexed pollId, address indexed voter, bool support);

    error InvalidConfig();
    error NotMember();
    error InvalidDuration();
    error UnknownPoll();
    error VotingClosed();
    error AlreadyVoted();

    constructor(address[] memory members, uint256 _quorum, uint256 _thresholdBps) {
        for (uint256 i = 0; i < members.length; i++) {
            address m = members[i];
            if (m == address(0) || isMember[m]) revert InvalidConfig();
            isMember[m] = true;
        }
        if (_quorum == 0 || _quorum > members.length) revert InvalidConfig();
        if (_thresholdBps == 0 || _thresholdBps > BPS) revert InvalidConfig();
        memberCount = members.length;
        quorum = _quorum;
        thresholdBps = _thresholdBps;
    }

    function createPoll(bytes32 topic, uint256 duration) external returns (uint256 pollId) {
        if (!isMember[msg.sender]) revert NotMember();
        if (duration == 0) revert InvalidDuration();

        pollId = pollCount++;
        Poll storage p = polls[pollId];
        p.topic = topic;
        p.deadline = block.timestamp + duration;
        emit PollCreated(pollId, topic, p.deadline);
    }

    function vote(uint256 pollId, bool support) external {
        if (!isMember[msg.sender]) revert NotMember();
        if (pollId >= pollCount) revert UnknownPoll();
        Poll storage p = polls[pollId];
        if (block.timestamp >= p.deadline) revert VotingClosed();
        if (hasVoted[pollId][msg.sender]) revert AlreadyVoted();

        hasVoted[pollId][msg.sender] = true;
        if (support) {
            p.yesVotes += 1;
        } else {
            p.noVotes += 1;
        }
        emit VoteCast(pollId, msg.sender, support);
    }

    function getPoll(uint256 pollId)
        external
        view
        returns (bytes32 topic, uint256 deadline, uint256 yesVotes, uint256 noVotes)
    {
        if (pollId >= pollCount) revert UnknownPoll();
        Poll storage p = polls[pollId];
        return (p.topic, p.deadline, p.yesVotes, p.noVotes);
    }

    function outcome(uint256 pollId) external view returns (Outcome) {
        if (pollId >= pollCount) revert UnknownPoll();
        Poll storage p = polls[pollId];
        if (block.timestamp < p.deadline) return Outcome.Pending;

        uint256 total = p.yesVotes + p.noVotes;
        if (total < quorum) return Outcome.QuorumNotMet;

        // Cross-multiplication avoids the rounding of an integer division.
        if (p.yesVotes * BPS >= thresholdBps * total) return Outcome.Passed;
        return Outcome.Rejected;
    }
}
