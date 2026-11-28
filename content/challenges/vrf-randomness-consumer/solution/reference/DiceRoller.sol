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
        if (coordinator_ == address(0)) revert ZeroAddress();
        coordinator = IVRFCoordinatorLike(coordinator_);
        keyHash = keyHash_;
    }

    function resultsOf(uint256 requestId) external view returns (uint256[] memory) {
        return _results[requestId];
    }

    function requestRoll(uint8 sides, uint8 diceCount) external returns (uint256 requestId) {
        if (sides < MIN_SIDES || sides > MAX_SIDES) revert InvalidSides();
        if (diceCount == 0 || diceCount > MAX_DICE) revert InvalidDiceCount();
        if (hasPendingRoll[msg.sender]) revert RollInProgress();

        // Set the flag before calling out so a coordinator that calls back into
        // requestRoll cannot open a second pending roll for the same player.
        hasPendingRoll[msg.sender] = true;

        requestId = coordinator.requestRandomWords(keyHash, diceCount);

        // The id is chosen by the coordinator. Never overwrite an existing request.
        Request storage r = requests[requestId];
        if (r.status != Status.None) revert DuplicateRequestId();

        r.player = msg.sender;
        r.sides = sides;
        r.diceCount = diceCount;
        r.status = Status.Pending;
        r.requestedAt = uint64(block.timestamp);
        lastRequestId[msg.sender] = requestId;

        emit RollRequested(requestId, msg.sender, sides, diceCount);
    }

    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external {
        if (msg.sender != address(coordinator)) revert OnlyCoordinator();
        Request storage r = requests[requestId];
        if (r.status != Status.Pending) revert RequestNotPending();
        if (randomWords.length != r.diceCount) revert WrongWordCount();

        uint256 sides = r.sides;
        uint256 total;
        uint256[] storage out = _results[requestId];
        for (uint256 i = 0; i < randomWords.length; ++i) {
            // % sides gives 0 .. sides-1; dice are numbered from 1.
            uint256 face = (randomWords[i] % sides) + 1;
            out.push(face);
            total += face;
        }

        r.status = Status.Fulfilled;
        r.total = total;
        hasPendingRoll[r.player] = false;
        rollsCompleted[r.player] += 1;

        emit RollFulfilled(requestId, r.player, total);
    }

    function cancelRoll(uint256 requestId) external {
        Request storage r = requests[requestId];
        if (r.status != Status.Pending) revert RequestNotPending();
        if (r.player != msg.sender) revert NotRequester();
        if (block.timestamp < uint256(r.requestedAt) + REQUEST_TIMEOUT) revert NotTimedOut();

        r.status = Status.Cancelled;
        hasPendingRoll[msg.sender] = false;

        emit RollCancelled(requestId, msg.sender);
    }
}
