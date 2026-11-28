// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DiceRoller.sol";

interface IVRFConsumerLike {
    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external;
}

contract MockVRFCoordinator is IVRFCoordinatorLike {
    uint256 public nextRequestId = 1;
    bool public reuseIds;
    mapping(uint256 => address) public consumerOf;
    mapping(uint256 => uint32) public numWordsOf;
    bytes32 public lastKeyHash;

    function setNextRequestId(uint256 id) external {
        nextRequestId = id;
    }

    function setReuseIds(bool on) external {
        reuseIds = on;
    }

    function requestRandomWords(bytes32 keyHash, uint32 numWords) external override returns (uint256 requestId) {
        requestId = nextRequestId;
        if (!reuseIds) nextRequestId = requestId + 1;
        consumerOf[requestId] = msg.sender;
        numWordsOf[requestId] = numWords;
        lastKeyHash = keyHash;
    }

    function fulfill(uint256 requestId, uint256[] memory words) external {
        IVRFConsumerLike(consumerOf[requestId]).rawFulfillRandomWords(requestId, words);
    }

    function fulfillTo(address consumer, uint256 requestId, uint256[] memory words) external {
        IVRFConsumerLike(consumer).rawFulfillRandomWords(requestId, words);
    }
}

contract DiceRollerTest is Test {
    bytes32 internal constant KEY_HASH = keccak256("key-hash");

    MockVRFCoordinator public coordinator;
    DiceRoller public roller;

    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        coordinator = new MockVRFCoordinator();
        roller = new DiceRoller(address(coordinator), KEY_HASH);
    }

    function _words(uint256 a) internal pure returns (uint256[] memory w) {
        w = new uint256[](1);
        w[0] = a;
    }

    function _words(uint256 a, uint256 b) internal pure returns (uint256[] memory w) {
        w = new uint256[](2);
        w[0] = a;
        w[1] = b;
    }

    function testRequestStoresPendingRoll() public {
        vm.prank(alice);
        uint256 id = roller.requestRoll(6, 2);

        assertEq(id, 1);
        (address player, uint8 sides, uint8 diceCount, DiceRoller.Status status, uint64 requestedAt, uint256 total) =
            roller.requests(id);
        assertEq(player, alice);
        assertEq(uint256(sides), 6);
        assertEq(uint256(diceCount), 2);
        assertEq(uint256(status), uint256(DiceRoller.Status.Pending));
        assertEq(uint256(requestedAt), block.timestamp);
        assertEq(total, 0);
        assertTrue(roller.hasPendingRoll(alice));
        assertEq(roller.lastRequestId(alice), id);

        // the coordinator was asked for one word per die with the configured key hash
        assertEq(uint256(coordinator.numWordsOf(id)), 2);
        assertEq(coordinator.lastKeyHash(), KEY_HASH);
    }

    function testFulfilmentMapsWordsToDice() public {
        vm.prank(alice);
        uint256 id = roller.requestRoll(6, 2);

        coordinator.fulfill(id, _words(12, 5)); // 12 % 6 + 1 = 1, 5 % 6 + 1 = 6

        uint256[] memory results = roller.resultsOf(id);
        assertEq(results.length, 2);
        assertEq(results[0], 1);
        assertEq(results[1], 6);

        (,,, DiceRoller.Status status,, uint256 total) = roller.requests(id);
        assertEq(uint256(status), uint256(DiceRoller.Status.Fulfilled));
        assertEq(total, 7);
        assertFalse(roller.hasPendingRoll(alice));
        assertEq(roller.rollsCompleted(alice), 1);
    }

    function testOnlyCoordinatorCanFulfil() public {
        vm.prank(alice);
        uint256 id = roller.requestRoll(6, 1);

        vm.prank(alice);
        vm.expectRevert(DiceRoller.OnlyCoordinator.selector);
        roller.rawFulfillRandomWords(id, _words(3));
    }

    function testCannotFulfilTwice() public {
        vm.prank(alice);
        uint256 id = roller.requestRoll(6, 1);
        coordinator.fulfill(id, _words(3));

        vm.expectRevert(DiceRoller.RequestNotPending.selector);
        coordinator.fulfill(id, _words(4));
    }

    function testOnePendingRollPerPlayer() public {
        vm.prank(alice);
        roller.requestRoll(6, 1);

        vm.prank(alice);
        vm.expectRevert(DiceRoller.RollInProgress.selector);
        roller.requestRoll(6, 1);

        vm.prank(bob); // other players are unaffected
        uint256 id2 = roller.requestRoll(20, 1);
        assertEq(id2, 2);
    }

    function testCancelAfterTimeout() public {
        vm.prank(alice);
        uint256 id = roller.requestRoll(6, 1);

        vm.warp(block.timestamp + 1 days);
        vm.prank(alice);
        roller.cancelRoll(id);

        assertFalse(roller.hasPendingRoll(alice));
        (,,, DiceRoller.Status status,,) = roller.requests(id);
        assertEq(uint256(status), uint256(DiceRoller.Status.Cancelled));
    }
}
