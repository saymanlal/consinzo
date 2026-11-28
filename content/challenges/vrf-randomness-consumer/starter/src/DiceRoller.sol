// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Minimal VRF-style coordinator: returns a request id now, calls back later.
interface IVRFCoordinatorLike {
    function requestRandomWords(bytes32 keyHash, uint32 numWords) external returns (uint256 requestId);
}

contract DiceRoller {
    enum Status {
        None,
        Pending,
        Fulfilled,
        Cancelled
    }

    struct Request {
        address player;
        uint8 sides;
        uint8 diceCount;
        Status status;
        uint64 requestedAt;
        uint256 total;
    }

    uint256 public constant MAX_DICE = 5;
    uint256 public constant MIN_SIDES = 2;
    uint256 public constant MAX_SIDES = 100;
    uint256 public constant REQUEST_TIMEOUT = 1 days;

    IVRFCoordinatorLike public immutable coordinator;
    bytes32 public immutable keyHash;

    mapping(uint256 => Request) public requests;
    mapping(address => bool) public hasPendingRoll;
    mapping(address => uint256) public lastRequestId;
    mapping(address => uint256) public rollsCompleted;
    mapping(uint256 => uint256[]) internal _results;

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

    constructor(address coordinator_, bytes32 keyHash_) {
        // TODO: revert with ZeroAddress() if coordinator_ is zero
        coordinator = IVRFCoordinatorLike(coordinator_);
        keyHash = keyHash_;
    }

    function resultsOf(uint256 requestId) external view returns (uint256[] memory) {
        return _results[requestId];
    }

    function requestRoll(uint8 sides, uint8 diceCount) external returns (uint256 requestId) {
        // TODO: validate sides (InvalidSides), diceCount (InvalidDiceCount), one pending roll per player (RollInProgress)
        // TODO: request diceCount words from the coordinator; the return value is the request id
        // TODO: revert with DuplicateRequestId() if that id is already used
        // TODO: store the Pending request, set hasPendingRoll / lastRequestId, emit RollRequested
        revert("NOT_IMPLEMENTED");
    }

    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external {
        // TODO: checks in order: OnlyCoordinator, RequestNotPending, WrongWordCount
        // TODO: die i = randomWords[i] % sides + 1; store each value and the total
        // TODO: mark Fulfilled, clear the pending flag, bump rollsCompleted, emit RollFulfilled
        revert("NOT_IMPLEMENTED");
    }

    function cancelRoll(uint256 requestId) external {
        // TODO: checks in order: RequestNotPending, NotRequester, NotTimedOut
        // TODO: mark Cancelled, clear the pending flag, emit RollCancelled
        revert("NOT_IMPLEMENTED");
    }
}
