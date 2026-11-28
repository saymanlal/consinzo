// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Timelocked executor for proposals relayed from a governor on another chain.
contract GovernanceReceiver {
    enum State {
        None,
        Queued,
        Executed,
        Cancelled,
        Expired
    }

    struct Proposal {
        bytes32 actionsHash;
        uint64 eta;
        State status; // only None, Queued, Executed or Cancelled is ever stored
    }

    uint256 public constant MIN_DELAY = 1 hours;
    uint256 public constant MAX_DELAY = 30 days;
    uint256 public constant GRACE_PERIOD = 7 days;

    address public immutable messenger;
    uint256 public immutable remoteChainId;

    address public remoteGovernor;
    address public guardian;
    uint256 public delay;

    mapping(uint256 => Proposal) internal _proposals;

    event ProposalQueued(uint256 indexed proposalId, bytes32 actionsHash, uint256 eta);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    event DelayUpdated(uint256 newDelay);
    event RemoteGovernorUpdated(address newGovernor);
    event GuardianUpdated(address newGuardian);

    error ZeroAddress();
    error InvalidDelay();
    error NotMessenger();
    error UntrustedSource();
    error InvalidProposal();
    error ProposalExists();
    error NotQueued();
    error TimelockNotElapsed();
    error ProposalExpired();
    error ActionsMismatch();
    error CallFailed(uint256 index);
    error NotGuardian();
    error OnlySelf();

    constructor(address messenger_, uint256 remoteChainId_, address remoteGovernor_, address guardian_, uint256 delay_) {
        // TODO: ZeroAddress() for a zero messenger or governor, InvalidDelay() outside MIN_DELAY..MAX_DELAY
        messenger = messenger_;
        remoteChainId = remoteChainId_;
        remoteGovernor = remoteGovernor_;
        guardian = guardian_;
        delay = delay_;
    }

    receive() external payable {}

    // ------------------------------------------------------------------ views

    function state(uint256 proposalId) public view returns (State) {
        // TODO: None for unknown ids; Expired for a queued proposal past eta + GRACE_PERIOD; otherwise the stored status
        revert("NOT_IMPLEMENTED");
    }

    function etaOf(uint256 proposalId) external view returns (uint256) {
        return _proposals[proposalId].eta;
    }

    function actionsHashOf(uint256 proposalId) external view returns (bytes32) {
        return _proposals[proposalId].actionsHash;
    }

    function hashActions(address[] calldata targets, uint256[] calldata values, bytes[] calldata calldatas)
        public
        pure
        returns (bytes32)
    {
        // TODO: keccak256(abi.encode(targets, values, calldatas))
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------------ receiving

    function receiveMessage(uint256 sourceChainId, address sourceSender, bytes calldata payload) external {
        // TODO: checks in order: NotMessenger, UntrustedSource (chain id AND sender), InvalidProposal, ProposalExists
        // TODO: payload is abi.encode(uint256 proposalId, address[] targets, uint256[] values, bytes[] calldatas)
        // TODO: store the actions hash and eta = block.timestamp + delay, emit ProposalQueued
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------------ executing

    function execute(
        uint256 proposalId,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas
    ) external {
        // TODO: checks in order: NotQueued, TimelockNotElapsed, ProposalExpired, ActionsMismatch
        // TODO: mark the proposal executed before making any call
        // TODO: perform each call with its value; revert with CallFailed(i) if call i fails
        // TODO: emit ProposalExecuted
        revert("NOT_IMPLEMENTED");
    }

    function cancel(uint256 proposalId) external {
        // TODO: NotGuardian first, then NotQueued; mark cancelled, emit ProposalCancelled
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------------ self-administration

    modifier onlySelf() {
        // TODO: revert with OnlySelf() unless the receiver itself is the caller
        _;
    }

    function setDelay(uint256 newDelay) external onlySelf {
        // TODO: enforce MIN_DELAY..MAX_DELAY (InvalidDelay), store, emit DelayUpdated
        revert("NOT_IMPLEMENTED");
    }

    function setRemoteGovernor(address newGovernor) external onlySelf {
        // TODO: reject zero (ZeroAddress), store, emit RemoteGovernorUpdated
        revert("NOT_IMPLEMENTED");
    }

    function setGuardian(address newGuardian) external onlySelf {
        // TODO: store (zero allowed), emit GuardianUpdated
        revert("NOT_IMPLEMENTED");
    }
}
