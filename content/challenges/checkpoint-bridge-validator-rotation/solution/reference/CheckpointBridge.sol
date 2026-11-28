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
        return _inSet[epoch][account];
    }

    /// @notice Smallest number of attestations that is strictly more than two thirds.
    function quorum() public view returns (uint256) {
        return (validatorCount * 2) / 3 + 1;
    }

    function rotationHash(uint256 newEpoch, address[] memory newValidators) public pure returns (bytes32) {
        return keccak256(abi.encode(newEpoch, newValidators));
    }

    function rotationVotes(bytes32 proposal) external view returns (uint256) {
        return _rotationVotes[epoch][proposal];
    }

    function checkpointVotes(uint256 checkpointId, bytes32 root) external view returns (uint256) {
        return _rootVotes[epoch][checkpointId][root];
    }

    /// @notice Attest that `newValidators` should replace the current set.
    function attestRotation(address[] calldata newValidators) external {
        uint256 e = epoch;
        if (!_inSet[e][msg.sender]) revert NotValidator();
        _checkSet(newValidators);
        // The proposal commits to the epoch it creates, so attestations collected in one
        // epoch are meaningless in any other.
        bytes32 proposal = rotationHash(e + 1, newValidators);
        if (_votedRotation[e][proposal][msg.sender]) revert AlreadyAttested();
        _votedRotation[e][proposal][msg.sender] = true;
        uint256 votes = ++_rotationVotes[e][proposal];
        emit RotationAttested(proposal, msg.sender, votes);

        if (votes >= quorum()) {
            _installSet(newValidators);
        }
    }

    // -------------------------------------------------------------- checkpoints

    function attestCheckpoint(uint256 checkpointId, bytes32 root) external {
        uint256 e = epoch;
        if (!_inSet[e][msg.sender]) revert NotValidator();
        if (root == bytes32(0)) revert InvalidRoot();
        if (checkpointRoot[checkpointId] != bytes32(0)) revert CheckpointFinal();
        // One vote per validator per checkpoint, whatever the root: a validator cannot
        // back two competing roots.
        if (_votedCheckpoint[e][checkpointId][msg.sender]) revert AlreadyAttested();
        _votedCheckpoint[e][checkpointId][msg.sender] = true;

        // Votes are stored under the epoch in which they were cast. After a rotation the
        // tally restarts, so validators that left the set no longer count towards quorum.
        uint256 votes = ++_rootVotes[e][checkpointId][root];
        emit CheckpointAttested(checkpointId, root, msg.sender, votes);

        if (votes >= quorum()) {
            checkpointRoot[checkpointId] = root;
            emit CheckpointAccepted(checkpointId, root);
        }
    }

    // -------------------------------------------------------------- withdrawals

    /// @notice Leaf for a withdrawal. Hashed twice so that a 64-byte inner node can never
    ///         be presented as a leaf.
    function leafOf(uint256 nonce, address recipient, uint256 amount) public pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(nonce, recipient, amount))));
    }

    function verifyProof(bytes32 root, bytes32 leaf, uint256 index, bytes32[] calldata proof)
        public
        pure
        returns (bool)
    {
        bytes32 node = leaf;
        uint256 len = proof.length;
        for (uint256 i = 0; i < len; i++) {
            // The low bit of the index says whether the node is a right or a left child.
            node = index & 1 == 1 ? keccak256(abi.encode(proof[i], node)) : keccak256(abi.encode(node, proof[i]));
            index >>= 1;
        }
        // Left-over index bits mean the position does not exist in a tree of this depth.
        return index == 0 && node == root;
    }

    function withdraw(
        uint256 checkpointId,
        uint256 index,
        uint256 nonce,
        address recipient,
        uint256 amount,
        bytes32[] calldata proof
    ) external {
        bytes32 root = checkpointRoot[checkpointId];
        if (root == bytes32(0)) revert UnknownCheckpoint();
        // Keyed by nonce alone: the same withdrawal may be included in several
        // checkpoints and must still be paid once.
        if (withdrawn[nonce]) revert AlreadyWithdrawn();
        if (!verifyProof(root, leafOf(nonce, recipient, amount), index, proof)) revert InvalidProof();

        withdrawn[nonce] = true; // before the external call
        (bool ok,) = recipient.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit Withdrawal(nonce, recipient, amount);
    }

    // ----------------------------------------------------------------- internal

    /// @dev Non-empty, at most MAX_VALIDATORS, strictly ascending (hence unique, non-zero).
    function _checkSet(address[] memory set) internal pure {
        uint256 n = set.length;
        if (n == 0 || n > MAX_VALIDATORS) revert InvalidValidatorSet();
        address prev = address(0);
        for (uint256 i = 0; i < n; i++) {
            if (set[i] <= prev) revert InvalidValidatorSet();
            prev = set[i];
        }
    }

    function _installSet(address[] memory set) internal {
        _checkSet(set);
        uint256 e = ++epoch;
        uint256 n = set.length;
        for (uint256 i = 0; i < n; i++) {
            _inSet[e][set[i]] = true;
        }
        validatorCount = n;
        emit ValidatorSetRotated(e, n);
    }
}
