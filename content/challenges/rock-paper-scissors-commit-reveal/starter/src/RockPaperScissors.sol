// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title Two-player staked rock-paper-scissors with hidden moves.
contract RockPaperScissors {
    enum Move {
        None,
        Rock,
        Paper,
        Scissors
    }

    enum Phase {
        Waiting,
        Reveal,
        Finished
    }

    uint256 public immutable stake;
    uint256 public immutable revealPeriod;

    Phase public phase;
    address public player1;
    address public player2;
    uint256 public revealDeadline;
    address public winner;

    mapping(address => bytes32) public commitments;
    mapping(address => Move) public revealedMove;
    mapping(address => uint256) public winnings;

    event Joined(address indexed player);
    event Revealed(address indexed player, Move move);
    event Settled(address indexed winner);

    error InvalidConfig();
    error WrongPhase();
    error WrongStake();
    error InvalidCommitment();
    error AlreadyJoined();
    error NotPlayer();
    error RevealClosed();
    error RevealPending();
    error AlreadyRevealed();
    error InvalidMove();
    error CommitmentMismatch();
    error NothingToWithdraw();
    error TransferFailed();

    constructor(uint256 _stake, uint256 _revealPeriod) {
        if (_stake == 0 || _revealPeriod == 0) revert InvalidConfig();
        stake = _stake;
        revealPeriod = _revealPeriod;
    }

    /// @notice The commitment a player must submit for `move` and `salt`.
    function commitmentOf(address player, Move move, bytes32 salt) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(player, uint8(move), salt));
    }

    function join(bytes32 commitment) external payable {
        // TODO: Check phase, stake, commitment and that player1 does not join twice.
        // TODO: Seat the caller; when the second player joins, start the reveal phase and its deadline. Emit Joined.
        revert("NOT_IMPLEMENTED");
    }

    function leave() external {
        // TODO: Only player1, only while waiting. Free the seat and credit the stake to winnings.
        revert("NOT_IMPLEMENTED");
    }

    function reveal(Move move, bytes32 salt) external {
        // TODO: Check phase, deadline, that the caller is a player who has not revealed, and the move.
        // TODO: Verify the commitment and store the move. Emit Revealed.
        revert("NOT_IMPLEMENTED");
    }

    function settle() external {
        // TODO: Allowed once both revealed, or once the deadline has passed.
        // TODO: Credit the pot through winnings: winner takes all, draw or no reveals splits, a lone revealer wins.
        // TODO: Set phase, winner and emit Settled.
        revert("NOT_IMPLEMENTED");
    }

    function withdraw() external {
        // TODO: Pay out the caller's winnings, zeroing them before the transfer.
        revert("NOT_IMPLEMENTED");
    }
}
