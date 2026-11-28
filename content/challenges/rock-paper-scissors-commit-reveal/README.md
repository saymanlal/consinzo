# Rock-Paper-Scissors with Commit-Reveal and Reveal Timeout

## Problem Statement

Implement `RockPaperScissors` in `src/RockPaperScissors.sol`: a single staked game between two
players.

On a public blockchain the second player could read the first player's move. The game therefore
runs in two steps: each player first submits a hash of their move (the commitment) together with
the stake, and only when both commitments are in do the players reveal. A player who does not
reveal in time loses to the one who did.

## Required Interface

```solidity
enum Move { None, Rock, Paper, Scissors }
enum Phase { Waiting, Reveal, Finished }

constructor(uint256 _stake, uint256 _revealPeriod)                              // provided
function commitmentOf(address player, Move move, bytes32 salt)
    public pure returns (bytes32)                                               // provided

function join(bytes32 commitment) external payable
function leave() external
function reveal(Move move, bytes32 salt) external
function settle() external
function withdraw() external

// public state (already declared in the starter)
uint256 public immutable stake;
uint256 public immutable revealPeriod;
Phase public phase;
address public player1;
address public player2;
uint256 public revealDeadline;
address public winner;                       // address(0) until settled, and for draws
mapping(address => bytes32) public commitments;
mapping(address => Move) public revealedMove;
mapping(address => uint256) public winnings;
```

The commitment is `keccak256(abi.encodePacked(player, uint8(move), salt))`, as computed by the
provided `commitmentOf`.

## Rules

1. `join(commitment)`
   - reverts with `WrongPhase()` unless `phase == Waiting`;
   - reverts with `WrongStake()` unless `msg.value == stake`;
   - reverts with `InvalidCommitment()` if `commitment == bytes32(0)`;
   - reverts with `AlreadyJoined()` if the caller is already `player1`;
   - the first caller becomes `player1`; the second becomes `player2`, which moves the game to
     `Reveal` and sets `revealDeadline = block.timestamp + revealPeriod`;
   - stores the commitment and emits `Joined(player)`.
2. `leave()` lets `player1` back out while still alone: it reverts with `WrongPhase()` unless
   `phase == Waiting` and with `NotPlayer()` unless the caller is `player1`. It clears `player1`
   and their commitment and credits `stake` to `winnings[caller]`. The game can then be joined
   again by anyone.
3. `reveal(move, salt)`
   - reverts with `WrongPhase()` unless `phase == Reveal`;
   - reverts with `RevealClosed()` when `block.timestamp >= revealDeadline`;
   - reverts with `NotPlayer()` if the caller is neither player;
   - reverts with `AlreadyRevealed()` if the caller already revealed;
   - reverts with `InvalidMove()` if `move == Move.None`;
   - reverts with `CommitmentMismatch()` unless `commitmentOf(msg.sender, move, salt)` equals the
     caller's stored commitment;
   - stores the move in `revealedMove[caller]` and emits `Revealed(player, move)`.
4. `settle()` can be called by anyone.
   - reverts with `WrongPhase()` unless `phase == Reveal`;
   - reverts with `RevealPending()` if not both players have revealed and
     `block.timestamp < revealDeadline`;
   - sets `phase = Finished` and distributes the pot of `2 * stake` through `winnings`:
     - both revealed: Rock beats Scissors, Scissors beats Paper, Paper beats Rock; the winner is
       credited the whole pot; equal moves are a draw and each player is credited `stake`;
     - exactly one revealed (deadline passed): that player wins the whole pot;
     - nobody revealed (deadline passed): each player is credited `stake`;
   - sets `winner` (left as `address(0)` when there is no winner) and emits `Settled(winner)`.
5. `withdraw()` pays the caller their `winnings` and zeroes them; reverts with
   `NothingToWithdraw()` if zero and `TransferFailed()` if the transfer fails.

The checks must be evaluated in the order listed.

## What the Tests Check

- Public tests: a full game with a winner, a draw, and the timeout win.
- Hidden tests: all nine move combinations, wrong salt, wrong move, a copied commitment, reveals
  after the deadline, early settlement, nobody revealing, double settlement, `leave`, stake
  checks, and exact payouts.
