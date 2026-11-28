// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/OptimisticBridge.sol";

/// @dev Tries to pull its credit several times from inside the ETH callback.
contract ReentrantClaimer {
    OptimisticBridge public bridge;
    uint256 public attempts;

    constructor(OptimisticBridge bridge_) {
        bridge = bridge_;
    }

    function pull() external {
        bridge.withdraw();
    }

    receive() external payable {
        if (attempts < 3) {
            attempts++;
            try bridge.withdraw() {} catch {}
        }
    }
}

contract RejectingReceiver {
    OptimisticBridge public bridge;

    constructor(OptimisticBridge bridge_) {
        bridge = bridge_;
    }

    function pull() external {
        bridge.withdraw();
    }

    receive() external payable {
        revert("no");
    }
}

contract OptimisticBridgeHiddenTest is Test {
    uint256 internal constant BOND = 1 ether;
    uint256 internal constant PERIOD = 1 days;
    uint256 internal constant SRC = 10;

    OptimisticBridge public bridge;
    address public arbiter = address(0xA4B1);
    address public relayer = address(0x4E1A);
    address public relayer2 = address(0x4E1B);
    address public challenger = address(0xC4A1);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        bridge = new OptimisticBridge(arbiter, BOND, PERIOD);
        _fund(20 ether);
        vm.deal(relayer, 50 ether);
        vm.deal(relayer2, 50 ether);
        vm.deal(challenger, 50 ether);
    }

    function _fund(uint256 amount) internal {
        (bool ok,) = address(bridge).call{value: amount}("");
        assertTrue(ok);
    }

    function _post(address who, uint256 nonce, address to, uint256 amount, uint256 bond) internal returns (bytes32 slot) {
        vm.prank(who);
        slot = bridge.postMessage{value: bond}(SRC, nonce, to, amount);
    }

    function _status(bytes32 slot) internal view returns (OptimisticBridge.Status) {
        return bridge.getClaim(slot).status;
    }

    function testHiddenConstructorValidation() public {
        vm.expectRevert(OptimisticBridge.InvalidConfig.selector);
        new OptimisticBridge(address(0), BOND, PERIOD);
        vm.expectRevert(OptimisticBridge.InvalidConfig.selector);
        new OptimisticBridge(arbiter, 0, PERIOD);
        vm.expectRevert(OptimisticBridge.InvalidConfig.selector);
        new OptimisticBridge(arbiter, BOND, 0);
    }

    function testHiddenPostValidationOrder() public {
        vm.startPrank(relayer);
        vm.expectRevert(OptimisticBridge.InvalidMessage.selector);
        bridge.postMessage{value: 0}(SRC, 1, address(0), 1 ether);
        vm.expectRevert(OptimisticBridge.InvalidMessage.selector);
        bridge.postMessage{value: BOND}(SRC, 1, alice, 0);
        vm.expectRevert(OptimisticBridge.BadBond.selector);
        bridge.postMessage{value: BOND - 1}(SRC, 1, alice, 1 ether);
        vm.expectRevert(OptimisticBridge.BadBond.selector);
        bridge.postMessage{value: BOND + 1}(SRC, 1, alice, 1 ether);
        bridge.postMessage{value: BOND}(SRC, 1, alice, 1 ether);
        vm.expectRevert(OptimisticBridge.BadBond.selector);
        bridge.postMessage{value: 0}(SRC, 1, alice, 1 ether); // bond is checked before the slot
        vm.stopPrank();
    }

    function testHiddenSlotIsPerChainAndNonce() public {
        bytes32 a = _post(relayer, 1, alice, 1 ether, BOND);
        vm.prank(relayer);
        bytes32 b = bridge.postMessage{value: BOND}(SRC + 1, 1, alice, 1 ether);
        assertTrue(a != b);
        assertEq(b, keccak256(abi.encode(SRC + 1, uint256(1))));
        assertTrue(_status(b) == OptimisticBridge.Status.Pending);
    }

    function testHiddenChallengeWindowBoundaries() public {
        uint256 t0 = block.timestamp;
        bytes32 s1 = _post(relayer, 1, alice, 1 ether, BOND);
        bytes32 s2 = _post(relayer, 2, alice, 1 ether, BOND);

        vm.warp(t0 + PERIOD - 1);
        vm.expectRevert(OptimisticBridge.ChallengeWindowOpen.selector);
        bridge.finalize(s1);
        vm.prank(challenger);
        bridge.challenge{value: BOND}(s1); // last second of the window

        vm.warp(t0 + PERIOD);
        vm.prank(challenger);
        vm.expectRevert(OptimisticBridge.ChallengeWindowClosed.selector);
        bridge.challenge{value: BOND}(s2);
        bridge.finalize(s2);
        assertTrue(_status(s2) == OptimisticBridge.Status.Finalized);
    }

    function testHiddenChallengedClaimNeverFinalizesByTimeout() public {
        bytes32 slot = _post(relayer, 1, alice, 19 ether, BOND);
        vm.prank(challenger);
        bridge.challenge{value: BOND}(slot);
        vm.warp(block.timestamp + 100 * PERIOD);
        vm.expectRevert(OptimisticBridge.NotPending.selector);
        bridge.finalize(slot);
        assertEq(bridge.credits(alice), 0);

        vm.prank(arbiter);
        bridge.resolve(slot, true);
        vm.expectRevert(OptimisticBridge.NotPending.selector);
        bridge.finalize(slot);
        assertEq(bridge.liquidity(), 20 ether);
    }

    function testHiddenChallengeStateChecks() public {
        bytes32 unknown = bridge.slotOf(SRC, 99);
        vm.startPrank(challenger);
        vm.expectRevert(OptimisticBridge.NotPending.selector);
        bridge.challenge{value: BOND}(unknown);
        vm.stopPrank();

        bytes32 slot = _post(relayer, 1, alice, 1 ether, BOND);
        vm.startPrank(challenger);
        vm.expectRevert(OptimisticBridge.BadBond.selector);
        bridge.challenge{value: BOND - 1}(slot);
        vm.expectRevert(OptimisticBridge.BadBond.selector);
        bridge.challenge{value: 2 * BOND}(slot);
        bridge.challenge{value: BOND}(slot);
        vm.expectRevert(OptimisticBridge.NotPending.selector);
        bridge.challenge{value: BOND}(slot); // only one challenge
        vm.stopPrank();
        assertEq(bridge.getClaim(slot).challenger, challenger);
    }

    function testHiddenUpheldClaimCannotBeChallengedAgain() public {
        bytes32 slot = _post(relayer, 1, alice, 1 ether, BOND);
        vm.prank(challenger);
        bridge.challenge{value: BOND}(slot);
        vm.prank(arbiter);
        bridge.resolve(slot, false);
        assertTrue(_status(slot) == OptimisticBridge.Status.Upheld);

        vm.prank(challenger);
        vm.expectRevert(OptimisticBridge.NotPending.selector);
        bridge.challenge{value: BOND}(slot);
        vm.prank(arbiter);
        vm.expectRevert(OptimisticBridge.NotChallenged.selector);
        bridge.resolve(slot, true); // cannot be re-judged
        assertEq(bridge.credits(challenger), 0);
    }

    function testHiddenResolveAccessAndState() public {
        bytes32 slot = _post(relayer, 1, alice, 1 ether, BOND);
        vm.prank(arbiter);
        vm.expectRevert(OptimisticBridge.NotChallenged.selector);
        bridge.resolve(slot, true);

        vm.prank(challenger);
        bridge.challenge{value: BOND}(slot);
        vm.prank(challenger);
        vm.expectRevert(OptimisticBridge.NotArbiter.selector);
        bridge.resolve(slot, true);
        vm.expectRevert(OptimisticBridge.NotArbiter.selector);
        bridge.resolve(slot, true); // not even the owner
    }

    function testHiddenSlotReusableAfterSlashOnly() public {
        bytes32 slot = _post(relayer, 1, bob, 19 ether, BOND); // forged recipient
        vm.prank(challenger);
        bridge.challenge{value: BOND}(slot);
        vm.prank(arbiter);
        bridge.resolve(slot, true);

        // honest relayer posts the real message for the same slot
        bytes32 again = _post(relayer2, 1, alice, 2 ether, BOND);
        assertEq(again, slot);
        OptimisticBridge.Claim memory c = bridge.getClaim(slot);
        assertEq(c.relayer, relayer2);
        assertEq(c.recipient, alice);
        assertEq(c.challenger, address(0));
        assertEq(c.postedAt, block.timestamp);

        vm.warp(block.timestamp + PERIOD);
        bridge.finalize(slot);
        assertEq(bridge.credits(alice), 2 ether);
        assertEq(bridge.credits(bob), 0);

        vm.prank(relayer2);
        vm.expectRevert(OptimisticBridge.SlotTaken.selector);
        bridge.postMessage{value: BOND}(SRC, 1, alice, 2 ether);
        vm.expectRevert(OptimisticBridge.NotPending.selector);
        bridge.finalize(slot); // no double payout
        assertEq(bridge.credits(alice), 2 ether);
    }

    function testHiddenBondChangeDoesNotAffectLiveClaims() public {
        bytes32 slot = _post(relayer, 1, alice, 1 ether, BOND);
        bridge.setBondAmount(3 ether);

        vm.prank(relayer);
        vm.expectRevert(OptimisticBridge.BadBond.selector);
        bridge.postMessage{value: BOND}(SRC, 2, alice, 1 ether);
        bytes32 slot2 = _post(relayer, 2, alice, 1 ether, 3 ether);

        // the old claim is still challenged with the old bond
        vm.prank(challenger);
        vm.expectRevert(OptimisticBridge.BadBond.selector);
        bridge.challenge{value: 3 ether}(slot);
        vm.prank(challenger);
        bridge.challenge{value: BOND}(slot);
        vm.prank(challenger);
        bridge.challenge{value: 3 ether}(slot2);

        vm.startPrank(arbiter);
        bridge.resolve(slot, true);
        bridge.resolve(slot2, false);
        vm.stopPrank();
        assertEq(bridge.credits(challenger), 2 * BOND);
        assertEq(bridge.credits(relayer), 3 ether);

        bridge.finalize(slot2);
        assertEq(bridge.credits(relayer), 6 ether);
    }

    function testHiddenSetBondAmountAccess() public {
        vm.prank(relayer);
        vm.expectRevert(OptimisticBridge.NotOwner.selector);
        bridge.setBondAmount(1);
        vm.expectRevert(OptimisticBridge.InvalidConfig.selector);
        bridge.setBondAmount(0);
    }

    function testHiddenBondsAndCreditsAreNotLiquidity() public {
        // 20 ETH of liquidity. Two claims of 15 ETH each; plenty of bond money sits in the
        // contract, but only one claim can be paid.
        bytes32 s1 = _post(relayer, 1, alice, 15 ether, BOND);
        bytes32 s2 = _post(relayer, 2, bob, 15 ether, BOND);
        for (uint256 i = 3; i < 13; i++) {
            _post(relayer2, i, alice, 1 ether, BOND);
        }
        assertEq(address(bridge).balance, 32 ether);
        vm.warp(block.timestamp + PERIOD);

        bridge.finalize(s1);
        assertEq(bridge.liquidity(), 5 ether);
        vm.expectRevert(OptimisticBridge.InsufficientLiquidity.selector);
        bridge.finalize(s2);
        assertTrue(_status(s2) == OptimisticBridge.Status.Pending);
        assertEq(bridge.credits(bob), 0);

        _fund(10 ether);
        bridge.finalize(s2); // retried once liquidity arrives
        assertEq(bridge.credits(bob), 15 ether);
        assertEq(bridge.liquidity(), 0);
    }

    function testHiddenWithdrawReentrancyPaysOnce() public {
        ReentrantClaimer attacker = new ReentrantClaimer(bridge);
        bytes32 slot = _post(relayer, 1, address(attacker), 4 ether, BOND);
        _post(relayer, 2, alice, 4 ether, BOND);
        vm.warp(block.timestamp + PERIOD);
        bridge.finalize(slot);

        attacker.pull();
        assertEq(address(attacker).balance, 4 ether);
        assertEq(bridge.credits(address(attacker)), 0);
        assertEq(address(bridge).balance, 20 ether + 2 * BOND - 4 ether);
        assertGt(attacker.attempts(), 0);
    }

    function testHiddenWithdrawFailures() public {
        vm.prank(bob);
        vm.expectRevert(OptimisticBridge.NothingToWithdraw.selector);
        bridge.withdraw();

        RejectingReceiver r = new RejectingReceiver(bridge);
        bytes32 slot = _post(relayer, 1, address(r), 4 ether, BOND);
        vm.warp(block.timestamp + PERIOD);
        bridge.finalize(slot);
        vm.expectRevert(OptimisticBridge.TransferFailed.selector);
        r.pull();
        assertEq(bridge.credits(address(r)), 4 ether); // credit survives the failed transfer

        // a recipient that cannot receive does not block the relayer
        vm.prank(relayer);
        assertEq(bridge.withdraw(), BOND);
    }

    function testHiddenSelfChallengeGainsNothing() public {
        // A relayer disputing its own forged claim only gets its two bonds back.
        bytes32 slot = _post(relayer, 1, relayer, 19 ether, BOND);
        vm.prank(relayer);
        bridge.challenge{value: BOND}(slot);
        vm.prank(arbiter);
        bridge.resolve(slot, true);
        vm.prank(relayer);
        bridge.withdraw();
        assertEq(relayer.balance, 50 ether);
        assertEq(bridge.liquidity(), 20 ether);
    }

    function testHiddenBalanceInvariantAfterMixedFlow() public {
        bytes32 s1 = _post(relayer, 1, alice, 3 ether, BOND);
        bytes32 s2 = _post(relayer, 2, bob, 4 ether, BOND);
        bytes32 s3 = _post(relayer2, 3, bob, 5 ether, BOND);
        bytes32 s4 = _post(relayer2, 4, alice, 6 ether, BOND); // stays pending

        vm.startPrank(challenger);
        bridge.challenge{value: BOND}(s2);
        bridge.challenge{value: BOND}(s3);
        vm.stopPrank();
        vm.startPrank(arbiter);
        bridge.resolve(s2, true);
        bridge.resolve(s3, false);
        vm.stopPrank();
        bridge.finalize(s3);
        vm.warp(block.timestamp + PERIOD);
        bridge.finalize(s1);
        vm.prank(alice);
        bridge.withdraw();

        uint256 credits = bridge.credits(alice) + bridge.credits(bob) + bridge.credits(relayer)
            + bridge.credits(relayer2) + bridge.credits(challenger);
        uint256 liveBonds = bridge.getClaim(s4).bond; // the only live claim
        assertEq(address(bridge).balance, bridge.liquidity() + liveBonds + credits);
        assertEq(bridge.liquidity(), 12 ether);
        assertEq(bridge.credits(challenger), 2 * BOND);
        assertEq(bridge.credits(relayer), BOND);
        assertEq(bridge.credits(relayer2), 2 * BOND);
        assertEq(bridge.credits(bob), 5 ether);
    }
}
