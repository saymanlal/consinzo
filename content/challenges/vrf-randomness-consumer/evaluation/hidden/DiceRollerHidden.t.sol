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

contract DiceRollerHiddenTest is Test {
    bytes32 internal constant KEY_HASH = keccak256("another-key-hash");

    MockVRFCoordinator public coordinator;
    DiceRoller public roller;

    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        coordinator = new MockVRFCoordinator();
        coordinator.setNextRequestId(1_000_003); // ids are whatever the coordinator says
        roller = new DiceRoller(address(coordinator), KEY_HASH);
    }

    function _words(uint256 n, uint256 seed) internal pure returns (uint256[] memory w) {
        w = new uint256[](n);
        for (uint256 i = 0; i < n; ++i) {
            w[i] = uint256(keccak256(abi.encode(seed, i)));
        }
    }

    function _status(uint256 id) internal view returns (uint256) {
        (,,, DiceRoller.Status status,,) = roller.requests(id);
        return uint256(status);
    }

    function testHiddenConstructor() public {
        vm.expectRevert(DiceRoller.ZeroAddress.selector);
        new DiceRoller(address(0), KEY_HASH);
        assertEq(address(roller.coordinator()), address(coordinator));
        assertEq(roller.keyHash(), KEY_HASH);
    }

    function testHiddenRequestIdComesFromCoordinator() public {
        vm.prank(alice);
        uint256 id = roller.requestRoll(6, 1);
        assertEq(id, 1_000_003);
        assertEq(roller.lastRequestId(alice), 1_000_003);
        assertEq(_status(1), 0);
        assertEq(_status(id), 1);
    }

    function testHiddenArgumentValidationAndOrder() public {
        vm.startPrank(alice);
        vm.expectRevert(DiceRoller.InvalidSides.selector);
        roller.requestRoll(1, 1);
        vm.expectRevert(DiceRoller.InvalidSides.selector);
        roller.requestRoll(0, 0);
        vm.expectRevert(DiceRoller.InvalidSides.selector);
        roller.requestRoll(101, 1);
        vm.expectRevert(DiceRoller.InvalidDiceCount.selector);
        roller.requestRoll(6, 0);
        vm.expectRevert(DiceRoller.InvalidDiceCount.selector);
        roller.requestRoll(6, 6);
        vm.stopPrank();
        assertFalse(roller.hasPendingRoll(alice));

        // boundaries are accepted
        vm.prank(alice);
        roller.requestRoll(2, 5);
        vm.prank(bob);
        roller.requestRoll(100, 1);
    }

    function testHiddenInvalidArgsReportedBeforeRollInProgress() public {
        vm.prank(alice);
        roller.requestRoll(6, 1);
        vm.prank(alice);
        vm.expectRevert(DiceRoller.InvalidDiceCount.selector);
        roller.requestRoll(6, 9);
    }

    function testHiddenFiveDiceRangeAndTotal() public {
        vm.prank(alice);
        uint256 id = roller.requestRoll(100, 5);
        uint256[] memory w = _words(5, 42);
        coordinator.fulfill(id, w);

        uint256[] memory r = roller.resultsOf(id);
        assertEq(r.length, 5);
        uint256 sum;
        for (uint256 i = 0; i < 5; ++i) {
            assertEq(r[i], (w[i] % 100) + 1);
            assertGe(r[i], 1);
            assertLe(r[i], 100);
            sum += r[i];
        }
        (,,,,, uint256 total) = roller.requests(id);
        assertEq(total, sum);
    }

    function testHiddenExtremeWords() public {
        vm.prank(alice);
        uint256 id = roller.requestRoll(2, 3);
        uint256[] memory w = new uint256[](3);
        w[0] = 0;
        w[1] = type(uint256).max; // odd
        w[2] = type(uint256).max - 1; // even
        coordinator.fulfill(id, w);
        uint256[] memory r = roller.resultsOf(id);
        assertEq(r[0], 1);
        assertEq(r[1], 2);
        assertEq(r[2], 1);
    }

    function testHiddenWrongWordCount() public {
        vm.prank(alice);
        uint256 id = roller.requestRoll(6, 3);

        vm.expectRevert(DiceRoller.WrongWordCount.selector);
        coordinator.fulfill(id, _words(2, 1));
        vm.expectRevert(DiceRoller.WrongWordCount.selector);
        coordinator.fulfill(id, _words(4, 1));
        vm.expectRevert(DiceRoller.WrongWordCount.selector);
        coordinator.fulfill(id, _words(0, 1));

        assertEq(_status(id), 1);
        assertEq(roller.resultsOf(id).length, 0);
        coordinator.fulfill(id, _words(3, 1));
        assertEq(_status(id), 2);
        assertEq(roller.resultsOf(id).length, 3);
    }

    function testHiddenUnknownRequestRejected() public {
        vm.expectRevert(DiceRoller.RequestNotPending.selector);
        coordinator.fulfillTo(address(roller), 777, _words(1, 1));
    }

    function testHiddenCheckOrderInFulfil() public {
        // unknown request and wrong caller: caller check wins
        vm.prank(alice);
        vm.expectRevert(DiceRoller.OnlyCoordinator.selector);
        roller.rawFulfillRandomWords(777, _words(1, 1));

        // fulfilled request and wrong word count: status check wins
        vm.prank(alice);
        uint256 id = roller.requestRoll(6, 1);
        coordinator.fulfill(id, _words(1, 1));
        vm.expectRevert(DiceRoller.RequestNotPending.selector);
        coordinator.fulfill(id, _words(3, 1));
    }

    function testHiddenPlayerCanRollAgainAfterFulfilment() public {
        vm.prank(alice);
        uint256 id1 = roller.requestRoll(6, 1);
        coordinator.fulfill(id1, _words(1, 7));
        uint256 first = roller.resultsOf(id1)[0];

        vm.prank(alice);
        uint256 id2 = roller.requestRoll(8, 2);
        assertEq(id2, id1 + 1);
        assertTrue(roller.hasPendingRoll(alice));
        coordinator.fulfill(id2, _words(2, 8));

        assertEq(roller.rollsCompleted(alice), 2);
        assertEq(roller.lastRequestId(alice), id2);
        // the first roll's results are untouched
        assertEq(roller.resultsOf(id1).length, 1);
        assertEq(roller.resultsOf(id1)[0], first);
    }

    function testHiddenInterleavedPlayersFulfilledOutOfOrder() public {
        vm.prank(alice);
        uint256 a = roller.requestRoll(6, 1);
        vm.prank(bob);
        uint256 b = roller.requestRoll(20, 2);

        coordinator.fulfill(b, _words(2, 3));
        assertFalse(roller.hasPendingRoll(bob));
        assertTrue(roller.hasPendingRoll(alice));
        assertEq(roller.rollsCompleted(bob), 1);
        assertEq(roller.rollsCompleted(alice), 0);

        coordinator.fulfill(a, _words(1, 4));
        assertFalse(roller.hasPendingRoll(alice));
        (address p,,,,,) = roller.requests(a);
        assertEq(p, alice);
    }

    function testHiddenDuplicateRequestIdRejected() public {
        coordinator.setReuseIds(true);
        vm.prank(alice);
        uint256 id = roller.requestRoll(6, 1);

        vm.prank(bob);
        vm.expectRevert(DiceRoller.DuplicateRequestId.selector);
        roller.requestRoll(20, 2);

        // alice's request is intact and bob is not locked out
        (address p, uint8 sides,,,,) = roller.requests(id);
        assertEq(p, alice);
        assertEq(uint256(sides), 6);
        assertFalse(roller.hasPendingRoll(bob));

        // even after fulfilment the id stays taken
        coordinator.fulfill(id, _words(1, 1));
        vm.prank(bob);
        vm.expectRevert(DiceRoller.DuplicateRequestId.selector);
        roller.requestRoll(20, 2);
    }

    function testHiddenCancelRules() public {
        uint256 t0 = block.timestamp;
        vm.prank(alice);
        uint256 id = roller.requestRoll(6, 1);

        vm.prank(alice);
        vm.expectRevert(DiceRoller.NotTimedOut.selector);
        roller.cancelRoll(id);

        vm.warp(t0 + 1 days - 1);
        vm.prank(alice);
        vm.expectRevert(DiceRoller.NotTimedOut.selector);
        roller.cancelRoll(id);

        vm.warp(t0 + 1 days);
        vm.prank(bob);
        vm.expectRevert(DiceRoller.NotRequester.selector);
        roller.cancelRoll(id);

        vm.prank(bob);
        vm.expectRevert(DiceRoller.RequestNotPending.selector);
        roller.cancelRoll(id + 50);

        vm.prank(alice);
        roller.cancelRoll(id);

        vm.prank(alice);
        vm.expectRevert(DiceRoller.RequestNotPending.selector);
        roller.cancelRoll(id);
    }

    function testHiddenLateFulfilmentAfterCancelRejected() public {
        vm.prank(alice);
        uint256 id1 = roller.requestRoll(6, 1);
        vm.warp(block.timestamp + 2 days);
        vm.prank(alice);
        roller.cancelRoll(id1);

        // alice starts a new roll; the late answer to the old one must not touch it
        vm.prank(alice);
        uint256 id2 = roller.requestRoll(6, 1);

        vm.expectRevert(DiceRoller.RequestNotPending.selector);
        coordinator.fulfill(id1, _words(1, 1));

        assertTrue(roller.hasPendingRoll(alice));
        assertEq(roller.rollsCompleted(alice), 0);
        assertEq(roller.resultsOf(id1).length, 0);
        assertEq(_status(id2), 1);

        coordinator.fulfill(id2, _words(1, 2));
        assertEq(roller.rollsCompleted(alice), 1);
    }

    function testHiddenCannotCancelFulfilledRoll() public {
        vm.prank(alice);
        uint256 id = roller.requestRoll(6, 1);
        coordinator.fulfill(id, _words(1, 1));
        vm.warp(block.timestamp + 2 days);
        vm.prank(alice);
        vm.expectRevert(DiceRoller.RequestNotPending.selector);
        roller.cancelRoll(id);
        assertEq(_status(id), 2);
    }
}
