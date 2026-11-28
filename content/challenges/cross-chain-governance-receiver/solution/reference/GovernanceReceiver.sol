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
        if (messenger_ == address(0) || remoteGovernor_ == address(0)) revert ZeroAddress();
        if (delay_ < MIN_DELAY || delay_ > MAX_DELAY) revert InvalidDelay();
        messenger = messenger_;
        remoteChainId = remoteChainId_;
        remoteGovernor = remoteGovernor_;
        guardian = guardian_;
        delay = delay_;
    }

    receive() external payable {}

    // ------------------------------------------------------------------ views

    function state(uint256 proposalId) public view returns (State) {
        Proposal storage p = _proposals[proposalId];
        if (p.status == State.Queued && block.timestamp > uint256(p.eta) + GRACE_PERIOD) {
            return State.Expired;
        }
        return p.status;
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
        return keccak256(abi.encode(targets, values, calldatas));
    }

    // ------------------------------------------------------------------ receiving

    function receiveMessage(uint256 sourceChainId, address sourceSender, bytes calldata payload) external {
        if (msg.sender != messenger) revert NotMessenger();
        // Both halves of the origin matter: the same address on another chain can be
        // controlled by someone else entirely.
        if (sourceChainId != remoteChainId || sourceSender != remoteGovernor) revert UntrustedSource();

        (uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            abi.decode(payload, (uint256, address[], uint256[], bytes[]));

        if (targets.length == 0 || targets.length != values.length || targets.length != calldatas.length) {
            revert InvalidProposal();
        }

        Proposal storage p = _proposals[proposalId];
        // Any non-None status blocks the id forever, so a cancelled or executed proposal
        // cannot be resurrected by redelivering the message.
        if (p.status != State.None) revert ProposalExists();

        bytes32 actionsHash = keccak256(abi.encode(targets, values, calldatas));
        uint256 eta = block.timestamp + delay;
        p.actionsHash = actionsHash;
        p.eta = uint64(eta);
        p.status = State.Queued;

        emit ProposalQueued(proposalId, actionsHash, eta);
    }

    // ------------------------------------------------------------------ executing

    function execute(
        uint256 proposalId,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas
    ) external {
        Proposal storage p = _proposals[proposalId];
        if (p.status != State.Queued) revert NotQueued();
        uint256 eta = p.eta;
        if (block.timestamp < eta) revert TimelockNotElapsed();
        if (block.timestamp > eta + GRACE_PERIOD) revert ProposalExpired();
        if (hashActions(targets, values, calldatas) != p.actionsHash) revert ActionsMismatch();

        // Effects before interactions: a target that calls back into execute() with the
        // same proposal finds it already executed.
        p.status = State.Executed;

        for (uint256 i = 0; i < targets.length; ++i) {
            (bool ok,) = targets[i].call{value: values[i]}(calldatas[i]);
            // Reverting undoes the status change above and every earlier action.
            if (!ok) revert CallFailed(i);
        }

        emit ProposalExecuted(proposalId);
    }

    function cancel(uint256 proposalId) external {
        if (msg.sender != guardian) revert NotGuardian();
        Proposal storage p = _proposals[proposalId];
        if (p.status != State.Queued) revert NotQueued();
        p.status = State.Cancelled;
        emit ProposalCancelled(proposalId);
    }

    // ------------------------------------------------------------------ self-administration

    modifier onlySelf() {
        if (msg.sender != address(this)) revert OnlySelf();
        _;
    }

    function setDelay(uint256 newDelay) external onlySelf {
        if (newDelay < MIN_DELAY || newDelay > MAX_DELAY) revert InvalidDelay();
        delay = newDelay;
        emit DelayUpdated(newDelay);
    }

    function setRemoteGovernor(address newGovernor) external onlySelf {
        if (newGovernor == address(0)) revert ZeroAddress();
        remoteGovernor = newGovernor;
        emit RemoteGovernorUpdated(newGovernor);
    }

    function setGuardian(address newGuardian) external onlySelf {
        guardian = newGuardian;
        emit GuardianUpdated(newGuardian);
    }
}
