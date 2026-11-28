// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Bridge exit contract secured by a rotating validator set.
///         Validators attest to checkpoint roots (Merkle roots of withdrawals on the other
///         chain) by calling the contract from their own address. A root is accepted once
///         more than two thirds of the current set have attested to it. Users then prove
///         inclusion of their withdrawal under an accepted root.
contract CheckpointBridge {
    uint256 public constant MAX_VALIDATORS = 32;

    /// @notice Current validator-set epoch. Starts at 1 and grows by one per rotation.
    uint256 public epoch;
    uint256 public validatorCount;
    mapping(uint256 => mapping(address => bool)) internal _inSet; // epoch => validator => member

    /// @notice Accepted root per checkpoint id; zero while not accepted.
    mapping(uint256 => bytes32) public checkpointRoot;
    // epoch => checkpoint id => root => votes
    mapping(uint256 => mapping(uint256 => mapping(bytes32 => uint256))) internal _rootVotes;
    // epoch => checkpoint id => validator => already voted
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) internal _votedCheckpoint;

    // epoch => proposal hash => votes / voter flags
    mapping(uint256 => mapping(bytes32 => uint256)) internal _rotationVotes;
    mapping(uint256 => mapping(bytes32 => mapping(address => bool))) internal _votedRotation;

    /// @notice Withdrawal nonces already paid, across all checkpoints.
    mapping(uint256 => bool) public withdrawn;

    event CheckpointAttested(uint256 indexed checkpointId, bytes32 root, address indexed validator, uint256 votes);
    event CheckpointAccepted(uint256 indexed checkpointId, bytes32 root);
    event RotationAttested(bytes32 indexed proposal, address indexed validator, uint256 votes);
    event ValidatorSetRotated(uint256 indexed newEpoch, uint256 validatorCount);
    event Withdrawal(uint256 indexed nonce, address indexed recipient, uint256 amount);

    error InvalidValidatorSet();
    error NotValidator();
    error InvalidRoot();
    error CheckpointFinal();
    error AlreadyAttested();
    error UnknownCheckpoint();
    error AlreadyWithdrawn();
    error InvalidProof();
    error TransferFailed();

    constructor(address[] memory validators_) {
        _installSet(validators_);
    }

    receive() external payable {}

    // ------------------------------------------------------------ validator set

    function isValidator(address account) public view returns (bool) {
        // TODO: membership in the current epoch's set
        revert("NOT_IMPLEMENTED");
    }

    /// @notice Smallest number of attestations that is strictly more than two thirds.
    function quorum() public view returns (uint256) {
        // TODO: smallest count strictly greater than two thirds of validatorCount
        revert("NOT_IMPLEMENTED");
    }

    function rotationHash(uint256 newEpoch, address[] memory newValidators) public pure returns (bytes32) {
        // TODO: keccak256(abi.encode(newEpoch, newValidators))
        revert("NOT_IMPLEMENTED");
    }

    function rotationVotes(bytes32 proposal) external view returns (uint256) {
        // TODO: votes for the proposal in the current epoch
        revert("NOT_IMPLEMENTED");
    }

    function checkpointVotes(uint256 checkpointId, bytes32 root) external view returns (uint256) {
        // TODO: votes for (checkpointId, root) in the current epoch
        revert("NOT_IMPLEMENTED");
    }

    /// @notice Attest that `newValidators` should replace the current set.
    function attestRotation(address[] calldata newValidators) external {
        // TODO: caller must be a current validator; the new set must be valid
        // TODO: one vote per validator per proposal; the proposal commits to epoch + 1
        // TODO: install the new set when quorum is reached
        revert("NOT_IMPLEMENTED");
    }

    // -------------------------------------------------------------- checkpoints

    function attestCheckpoint(uint256 checkpointId, bytes32 root) external {
        // TODO: caller must be a current validator; root non-zero; checkpoint not yet accepted
        // TODO: one vote per validator per checkpoint id, whatever the root
        // TODO: count votes for the current epoch only and accept the root at quorum
        revert("NOT_IMPLEMENTED");
    }

    // -------------------------------------------------------------- withdrawals

    /// @notice Leaf for a withdrawal. Hashed twice so that a 64-byte inner node can never
    ///         be presented as a leaf.
    function leafOf(uint256 nonce, address recipient, uint256 amount) public pure returns (bytes32) {
        // TODO: keccak256(bytes.concat(keccak256(abi.encode(nonce, recipient, amount))))
        revert("NOT_IMPLEMENTED");
    }

    function verifyProof(bytes32 root, bytes32 leaf, uint256 index, bytes32[] calldata proof)
        public
        pure
        returns (bool)
    {
        // TODO: walk from the leaf to the root; bit i of index selects left or right at level i
        // TODO: reject an index that does not fit in a tree of proof.length levels
        revert("NOT_IMPLEMENTED");
    }

    function withdraw(
        uint256 checkpointId,
        uint256 index,
        uint256 nonce,
        address recipient,
        uint256 amount,
        bytes32[] calldata proof
    ) external {
        // TODO: checkpoint must be accepted, nonce unused, proof valid (in this order)
        // TODO: mark the nonce before sending ETH; TransferFailed if the send fails
        revert("NOT_IMPLEMENTED");
    }

    // ----------------------------------------------------------------- internal

    /// @dev Non-empty, at most MAX_VALIDATORS, strictly ascending (hence unique, non-zero).
    function _checkSet(address[] memory set) internal pure {
        // TODO: non-empty, at most MAX_VALIDATORS, strictly ascending addresses
        revert("NOT_IMPLEMENTED");
    }

    function _installSet(address[] memory set) internal {
        // TODO: validate, start a new epoch, record members and validatorCount
        revert("NOT_IMPLEMENTED");
    }
}
