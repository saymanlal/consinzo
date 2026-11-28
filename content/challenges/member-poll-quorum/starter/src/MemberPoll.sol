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
        // TODO: Members only, non-zero duration.
        // TODO: Store the poll under the next id (starting at 0), emit PollCreated and return the id.
        revert("NOT_IMPLEMENTED");
    }

    function vote(uint256 pollId, bool support) external {
        // TODO: Members only, existing poll, before the deadline, once per member.
        // TODO: Count the vote and emit VoteCast.
        revert("NOT_IMPLEMENTED");
    }

    function getPoll(uint256 pollId)
        external
        view
        returns (bytes32 topic, uint256 deadline, uint256 yesVotes, uint256 noVotes)
    {
        // TODO: Revert for unknown ids, otherwise return the stored poll.
        revert("NOT_IMPLEMENTED");
    }

    function outcome(uint256 pollId) external view returns (Outcome) {
        // TODO: Pending before the deadline; then quorum; then the yes-share threshold (cross-multiplied).
        revert("NOT_IMPLEMENTED");
    }
}
