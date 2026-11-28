# VRF Randomness Consumer: Dice Roller

## Problem Statement

A contract cannot produce unpredictable randomness on its own. The usual integration is a
two-transaction flow against a verifiable-randomness coordinator: the consumer *requests*
random words and receives a request id, and some blocks later the coordinator calls the
consumer back to *fulfil* the request.

Implement `DiceRoller` in `src/DiceRoller.sol`. Players request a roll of 1 to 5 dice with a
chosen number of sides. The roll is settled when the coordinator delivers one random word
per die. A player whose request is never answered can cancel it after a timeout.

The coordinator used by the tests is a mock that implements `IVRFCoordinatorLike`
(declared in the starter).

## Interface

```solidity
enum Status { None, Pending, Fulfilled, Cancelled }

uint256 public constant MAX_DICE = 5;
uint256 public constant MIN_SIDES = 2;
uint256 public constant MAX_SIDES = 100;
uint256 public constant REQUEST_TIMEOUT = 1 days;

constructor(address coordinator_, bytes32 keyHash_)
function coordinator() external view returns (IVRFCoordinatorLike);
function keyHash() external view returns (bytes32);

function requests(uint256 requestId) external view
    returns (address player, uint8 sides, uint8 diceCount, Status status, uint64 requestedAt, uint256 total);
function hasPendingRoll(address player) external view returns (bool);
function lastRequestId(address player) external view returns (uint256);
function rollsCompleted(address player) external view returns (uint256);
function resultsOf(uint256 requestId) external view returns (uint256[] memory);

function requestRoll(uint8 sides, uint8 diceCount) external returns (uint256 requestId);
function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external;
function cancelRoll(uint256 requestId) external;

event RollRequested(uint256 indexed requestId, address indexed player, uint8 sides, uint8 diceCount);
event RollFulfilled(uint256 indexed requestId, address indexed player, uint256 total);
event RollCancelled(uint256 indexed requestId, address indexed player);

error ZeroAddress();
error InvalidSides();
error InvalidDiceCount();
error RollInProgress();
error DuplicateRequestId();
error OnlyCoordinator();
error RequestNotPending();
error WrongWordCount();
error NotRequester();
error NotTimedOut();
```

## Rules

1. The constructor reverts with `ZeroAddress()` if `coordinator_` is zero.
2. `requestRoll(sides, diceCount)`:
   - reverts with `InvalidSides()` unless `MIN_SIDES <= sides <= MAX_SIDES`;
   - then `InvalidDiceCount()` unless `1 <= diceCount <= MAX_DICE`;
   - then `RollInProgress()` if the caller already has a pending roll;
   - calls `coordinator.requestRandomWords(keyHash, diceCount)` and uses the returned value
     as the request id. If a request with that id already exists (its status is not
     `None`), reverts with `DuplicateRequestId()`;
   - stores the request as `Pending` with `requestedAt = block.timestamp`, sets
     `hasPendingRoll[caller] = true` and `lastRequestId[caller] = requestId`, emits
     `RollRequested` and returns the id.
3. `rawFulfillRandomWords(requestId, randomWords)` – checks in this order:
   - caller is the coordinator, else `OnlyCoordinator()`;
   - the request is `Pending`, else `RequestNotPending()` (unknown, already fulfilled and
     cancelled requests all fail here);
   - `randomWords.length == diceCount`, else `WrongWordCount()`.

   Die `i` shows `randomWords[i] % sides + 1`. The per-die values are stored in order and
   returned by `resultsOf`; `total` is their sum. The request becomes `Fulfilled`, the
   player's pending flag is cleared, `rollsCompleted[player]` increases by one and
   `RollFulfilled` is emitted.
4. `cancelRoll(requestId)` – checks in this order: the request is `Pending`
   (`RequestNotPending()`), the caller is its player (`NotRequester()`), and
   `block.timestamp >= requestedAt + REQUEST_TIMEOUT` (`NotTimedOut()`). The request
   becomes `Cancelled`, the pending flag is cleared and `RollCancelled` is emitted. A
   cancelled request can never be fulfilled.
5. `resultsOf` returns an empty array for requests that are not `Fulfilled`.

## What the tests check

- Request bookkeeping, the callback path and the mapping of random words to die values.
- That only the coordinator can fulfil, that a request is fulfilled at most once, and that
  word counts are enforced.
- One pending roll per player, independent players, cancellation after the timeout and the
  interaction between cancellation and late fulfilment.
