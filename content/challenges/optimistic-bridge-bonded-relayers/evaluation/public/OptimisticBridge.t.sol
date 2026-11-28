// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/OptimisticBridge.sol";

contract OptimisticBridgeTest is Test {
    uint256 internal constant BOND = 1 ether;
    uint256 internal constant PERIOD = 1 days;
    uint256 internal constant SRC = 10;

    OptimisticBridge public bridge;
    address public arbiter = address(0xA4B1);
    address public relayer = address(0x4E1A);
    address public challenger = address(0xC4A1);
    address public alice = address(0xA11CE);

    function setUp() public {
        bridge = new OptimisticBridge(arbiter, BOND, PERIOD);
        (bool ok,) = address(bridge).call{value: 100 ether}("");
        assertTrue(ok);
        vm.deal(relayer, 10 ether);
        vm.deal(challenger, 10 ether);
    }

    function _post(uint256 nonce, uint256 amount) internal returns (bytes32 slot) {
        vm.prank(relayer);
        slot = bridge.postMessage{value: BOND}(SRC, nonce, alice, amount);
    }

    function testConfigurationAndLiquidity() public view {
        assertEq(bridge.owner(), address(this));
        assertEq(bridge.arbiter(), arbiter);
        assertEq(bridge.bondAmount(), BOND);
        assertEq(bridge.challengePeriod(), PERIOD);
        assertEq(bridge.liquidity(), 100 ether);
        assertEq(bridge.slotOf(SRC, 7), keccak256(abi.encode(SRC, uint256(7))));
    }

    function testPostStoresPendingClaim() public {
        bytes32 slot = _post(1, 5 ether);
        assertEq(slot, bridge.slotOf(SRC, 1));
        OptimisticBridge.Claim memory c = bridge.getClaim(slot);
        assertEq(c.relayer, relayer);
        assertEq(c.recipient, alice);
        assertEq(c.amount, 5 ether);
        assertEq(c.bond, BOND);
        assertEq(c.postedAt, block.timestamp);
        assertTrue(c.status == OptimisticBridge.Status.Pending);
        assertEq(bridge.liquidity(), 100 ether); // the bond is not liquidity
    }

    function testUnchallengedClaimFinalizesAfterPeriod() public {
        bytes32 slot = _post(1, 5 ether);
        vm.expectRevert(OptimisticBridge.ChallengeWindowOpen.selector);
        bridge.finalize(slot);

        vm.warp(block.timestamp + PERIOD);
        bridge.finalize(slot);
        assertEq(bridge.credits(alice), 5 ether);
        assertEq(bridge.credits(relayer), BOND);
        assertEq(bridge.liquidity(), 95 ether);

        vm.prank(alice);
        assertEq(bridge.withdraw(), 5 ether);
        assertEq(alice.balance, 5 ether);
    }

    function testFraudulentClaimIsSlashed() public {
        bytes32 slot = _post(1, 50 ether);
        vm.prank(challenger);
        bridge.challenge{value: BOND}(slot);
        vm.prank(arbiter);
        bridge.resolve(slot, true);

        assertEq(bridge.credits(challenger), 2 * BOND);
        assertEq(bridge.credits(relayer), 0);
        assertTrue(bridge.getClaim(slot).status == OptimisticBridge.Status.None);
        vm.prank(challenger);
        bridge.withdraw();
        assertEq(challenger.balance, 11 ether);
        assertEq(bridge.liquidity(), 100 ether);
    }

    function testFailedChallengeRewardsRelayer() public {
        bytes32 slot = _post(1, 5 ether);
        vm.prank(challenger);
        bridge.challenge{value: BOND}(slot);
        vm.prank(arbiter);
        bridge.resolve(slot, false);
        assertEq(bridge.credits(relayer), BOND);

        bridge.finalize(slot); // upheld claims do not wait
        assertEq(bridge.credits(relayer), 2 * BOND);
        assertEq(bridge.credits(alice), 5 ether);
    }

    function testCannotPostSameSlotTwice() public {
        _post(1, 5 ether);
        vm.prank(relayer);
        vm.expectRevert(OptimisticBridge.SlotTaken.selector);
        bridge.postMessage{value: BOND}(SRC, 1, relayer, 9 ether);
    }
}
