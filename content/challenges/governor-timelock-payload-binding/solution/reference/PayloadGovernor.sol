// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title PayloadTimelock
/// @notice Holds the treasury and executes governor-approved calls after a delay.
contract PayloadTimelock {
    error NotDeployer();
    error GovernorAlreadySet();
    error NotGovernor();
    error AlreadyQueued();
    error NotQueued();
    error NotReady();
    error PayloadMismatch();
    error CallFailed();

    address private immutable _deployer;
    uint256 public immutable delay;
    address public governor;

    mapping(uint256 => uint256) public etaOf;
    /// @dev Payload commitment recorded at queue time; execute must present its preimage.
    mapping(uint256 => bytes32) public queuedHashOf;

    modifier onlyGovernor() {
        if (msg.sender != governor) revert NotGovernor();
        _;
    }

    constructor(uint256 delay_) {
        _deployer = msg.sender;
        delay = delay_;
    }

    receive() external payable {}

    function setGovernor(address governor_) external {
        if (msg.sender != _deployer) revert NotDeployer();
        if (governor != address(0)) revert GovernorAlreadySet();
        governor = governor_;
    }

    function queue(uint256 proposalId, bytes32 payloadHash) external onlyGovernor returns (uint256 eta) {
        if (etaOf[proposalId] != 0) revert AlreadyQueued();
        eta = block.timestamp + delay;
        etaOf[proposalId] = eta;
        queuedHashOf[proposalId] = payloadHash;
    }

    function execute(uint256 proposalId, address target, uint256 value, bytes calldata data) external onlyGovernor {
        uint256 eta = etaOf[proposalId];
        if (eta == 0) revert NotQueued();
        if (block.timestamp < eta) revert NotReady();
        // The treasury only releases the exact call that was queued.
        if (keccak256(abi.encode(target, value, data)) != queuedHashOf[proposalId]) revert PayloadMismatch();
        delete queuedHashOf[proposalId];
        delete etaOf[proposalId];
        (bool ok, ) = target.call{value: value}(data);
        if (!ok) revert CallFailed();
    }
}

/// @title PayloadGovernor
/// @notice One-voter-one-vote governor that queues passed proposals in a PayloadTimelock.
contract PayloadGovernor {
    uint256 public constant VOTING_PERIOD = 3 days;

    struct Proposal {
        uint256 voteEnd;
        uint256 forVotes;
        uint256 againstVotes;
        bool queued;
        bool executed;
        bytes32 payloadHash;
    }

    error NotVoter();
    error UnknownProposal();
    error AlreadyVoted();
    error VotingClosed();
    error VotingOpen();
    error ProposalDefeated();
    error AlreadyQueued();
    error NotQueued();
    error AlreadyExecuted();
    error PayloadMismatch();

    event ProposalCreated(uint256 indexed id, address indexed proposer, address target, uint256 value, bytes data);
    event VoteCast(uint256 indexed id, address indexed voter, bool support);
    event ProposalQueued(uint256 indexed id, uint256 eta);
    event ProposalExecuted(uint256 indexed id);

    PayloadTimelock public immutable timelock;
    uint256 public immutable quorum;
    mapping(address => bool) public isVoter;

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    constructor(address timelock_, address[] memory voters_, uint256 quorum_) {
        timelock = PayloadTimelock(payable(timelock_));
        quorum = quorum_;
        for (uint256 i = 0; i < voters_.length; i++) {
            isVoter[voters_[i]] = true;
        }
    }

    function hashPayload(address target, uint256 value, bytes memory data) public pure returns (bytes32) {
        return keccak256(abi.encode(target, value, data));
    }

    function payloadHashOf(uint256 id) external view returns (bytes32) {
        return proposals[id].payloadHash;
    }

    function propose(address target, uint256 value, bytes calldata data) external returns (uint256 id) {
        if (!isVoter[msg.sender]) revert NotVoter();
        id = ++proposalCount;
        proposals[id].voteEnd = block.timestamp + VOTING_PERIOD;
        // Commit to the payload before voting starts. This is what voters approve.
        proposals[id].payloadHash = hashPayload(target, value, data);
        emit ProposalCreated(id, msg.sender, target, value, data);
    }

    function castVote(uint256 id, bool support) external {
        if (!isVoter[msg.sender]) revert NotVoter();
        Proposal storage p = _get(id);
        if (block.timestamp >= p.voteEnd) revert VotingClosed();
        if (hasVoted[id][msg.sender]) revert AlreadyVoted();
        hasVoted[id][msg.sender] = true;
        if (support) p.forVotes += 1;
        else p.againstVotes += 1;
        emit VoteCast(id, msg.sender, support);
    }

    function queue(uint256 id) external {
        Proposal storage p = _get(id);
        if (block.timestamp < p.voteEnd) revert VotingOpen();
        if (p.forVotes <= p.againstVotes || p.forVotes < quorum) revert ProposalDefeated();
        if (p.queued) revert AlreadyQueued();
        p.queued = true;
        uint256 eta = timelock.queue(id, p.payloadHash);
        emit ProposalQueued(id, eta);
    }

    /// @notice Permissionless: anyone may trigger a queued proposal once its delay has passed.
    function execute(uint256 id, address target, uint256 value, bytes calldata data) external {
        Proposal storage p = _get(id);
        if (!p.queued) revert NotQueued();
        if (p.executed) revert AlreadyExecuted();
        if (hashPayload(target, value, data) != p.payloadHash) revert PayloadMismatch();
        p.executed = true;
        timelock.execute(id, target, value, data);
        emit ProposalExecuted(id);
    }

    function _get(uint256 id) private view returns (Proposal storage p) {
        p = proposals[id];
        if (p.voteEnd == 0) revert UnknownProposal();
    }
}
