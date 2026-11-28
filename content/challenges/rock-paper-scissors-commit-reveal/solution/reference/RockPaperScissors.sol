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
        if (phase != Phase.Waiting) revert WrongPhase();
        if (msg.value != stake) revert WrongStake();
        if (commitment == bytes32(0)) revert InvalidCommitment();
        if (msg.sender == player1) revert AlreadyJoined();

        commitments[msg.sender] = commitment;
        if (player1 == address(0)) {
            player1 = msg.sender;
        } else {
            player2 = msg.sender;
            phase = Phase.Reveal;
            revealDeadline = block.timestamp + revealPeriod;
        }
        emit Joined(msg.sender);
    }

    function leave() external {
        if (phase != Phase.Waiting) revert WrongPhase();
        if (msg.sender != player1 || msg.sender == address(0)) revert NotPlayer();

        player1 = address(0);
        delete commitments[msg.sender];
        winnings[msg.sender] += stake;
    }

    function reveal(Move move, bytes32 salt) external {
        if (phase != Phase.Reveal) revert WrongPhase();
        if (block.timestamp >= revealDeadline) revert RevealClosed();
        if (msg.sender != player1 && msg.sender != player2) revert NotPlayer();
        if (revealedMove[msg.sender] != Move.None) revert AlreadyRevealed();
        if (move == Move.None) revert InvalidMove();
        if (commitmentOf(msg.sender, move, salt) != commitments[msg.sender]) revert CommitmentMismatch();

        revealedMove[msg.sender] = move;
        emit Revealed(msg.sender, move);
    }

    function settle() external {
        if (phase != Phase.Reveal) revert WrongPhase();

        Move m1 = revealedMove[player1];
        Move m2 = revealedMove[player2];
        bool bothRevealed = m1 != Move.None && m2 != Move.None;
        if (!bothRevealed && block.timestamp < revealDeadline) revert RevealPending();

        phase = Phase.Finished;

        address result; // stays address(0) for a draw or when nobody revealed
        if (bothRevealed) {
            // Rock(1) < Paper(2) < Scissors(3) < Rock: a beats b when a is one step ahead.
            uint256 diff = (3 + uint256(m1) - uint256(m2)) % 3;
            if (diff == 1) result = player1;
            else if (diff == 2) result = player2;
        } else if (m1 != Move.None) {
            result = player1;
        } else if (m2 != Move.None) {
            result = player2;
        }

        if (result == address(0)) {
            winnings[player1] += stake;
            winnings[player2] += stake;
        } else {
            winnings[result] += 2 * stake;
        }
        winner = result;
        emit Settled(result);
    }

    function withdraw() external {
        uint256 amount = winnings[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        winnings[msg.sender] = 0;
        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}
