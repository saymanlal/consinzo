// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PayloadGovernor.sol";

contract Counter {
    uint256 public value;
    address public lastCaller;

    function set(uint256 v) external payable {
        value = v;
        lastCaller = msg.sender;
    }

    function fail() external pure {
        revert("NOPE");
    }
}

abstract contract GovFixture is Test {
    PayloadTimelock internal timelock;
    PayloadGovernor internal gov;
    Counter internal counter;
    address internal v1 = address(0x101);
    address internal v2 = address(0x102);
    address internal v3 = address(0x103);
    address internal grants = address(0x6A);
    address internal attacker = address(0xBAD);

    function _deploy() internal {
        timelock = new PayloadTimelock(2 days);
        address[] memory voters = new address[](3);
        voters[0] = v1;
        voters[1] = v2;
        voters[2] = v3;
        gov = new PayloadGovernor(address(timelock), voters, 2);
        timelock.setGovernor(address(gov));
        counter = new Counter();
        vm.deal(address(timelock), 100 ether);
    }

    /// Proposes, passes with two votes, queues and waits out the delay.
    function _passAndQueue(address target, uint256 value, bytes memory data) internal returns (uint256 id) {
        vm.prank(v1);
        id = gov.propose(target, value, data);
        vm.prank(v1);
        gov.castVote(id, true);
        vm.prank(v2);
        gov.castVote(id, true);
        vm.warp(block.timestamp + 3 days);
        gov.queue(id);
        vm.warp(block.timestamp + 2 days);
    }
}

contract PayloadGovernorHiddenTest is GovFixture {
    function setUp() public {
        _deploy();
    }

    function testHiddenEachPayloadFieldIsBound() public {
        bytes memory data = abi.encodeWithSelector(Counter.set.selector, uint256(7));
        uint256 id = _passAndQueue(address(counter), 1 ether, data);
        Counter other = new Counter();

        vm.expectRevert(PayloadGovernor.PayloadMismatch.selector);
        gov.execute(id, address(other), 1 ether, data);
        vm.expectRevert(PayloadGovernor.PayloadMismatch.selector);
        gov.execute(id, address(counter), 2 ether, data);
        vm.expectRevert(PayloadGovernor.PayloadMismatch.selector);
        gov.execute(id, address(counter), 1 ether, abi.encodeWithSelector(Counter.set.selector, uint256(8)));
        vm.expectRevert(PayloadGovernor.PayloadMismatch.selector);
        gov.execute(id, address(counter), 1 ether, "");

        gov.execute(id, address(counter), 1 ether, data);
        assertEq(counter.value(), 7);
        assertEq(counter.lastCaller(), address(timelock));
        assertEq(address(counter).balance, 1 ether);
        assertEq(other.value(), 0);
    }

    function testHiddenPayloadOfAnotherProposalCannotBeSwappedIn() public {
        // Proposal A (large grant) is created but never passes. Proposal B (small) passes.
        vm.prank(v3);
        uint256 a = gov.propose(attacker, 90 ether, "");
        uint256 b = _passAndQueue(grants, 1 ether, "");
        vm.expectRevert(PayloadGovernor.PayloadMismatch.selector);
        gov.execute(b, attacker, 90 ether, "");
        vm.expectRevert(PayloadGovernor.NotQueued.selector);
        gov.execute(a, attacker, 90 ether, "");
        assertEq(address(timelock).balance, 100 ether);
    }

    function testHiddenMismatchLeavesProposalExecutable() public {
        uint256 id = _passAndQueue(grants, 1 ether, "");
        vm.prank(attacker);
        vm.expectRevert(PayloadGovernor.PayloadMismatch.selector);
        gov.execute(id, attacker, 1 ether, "");
        assertTrue(timelock.etaOf(id) != 0);
        gov.execute(id, grants, 1 ether, "");
        assertEq(grants.balance, 1 ether);
        assertEq(timelock.etaOf(id), 0);
    }

    function testHiddenTimelockIsGovernorOnly() public {
        uint256 id = _passAndQueue(grants, 1 ether, "");
        vm.prank(attacker);
        vm.expectRevert(PayloadTimelock.NotGovernor.selector);
        timelock.execute(id, grants, 1 ether, "");
        vm.prank(attacker);
        vm.expectRevert(PayloadTimelock.NotGovernor.selector);
        timelock.queue(500, bytes32(0));
        vm.expectRevert(PayloadTimelock.GovernorAlreadySet.selector);
        timelock.setGovernor(attacker);
    }

    function testHiddenTimelockBindsQueuedHash() public {
        bytes memory data = abi.encodeWithSelector(Counter.set.selector, uint256(5));
        bytes32 h = gov.hashPayload(address(counter), 0, data);
        vm.startPrank(address(gov));
        timelock.queue(900, h);
        vm.expectRevert(PayloadTimelock.AlreadyQueued.selector);
        timelock.queue(900, h);
        vm.warp(block.timestamp + 2 days);
        vm.expectRevert(PayloadTimelock.PayloadMismatch.selector);
        timelock.execute(900, address(counter), 0, abi.encodeWithSelector(Counter.set.selector, uint256(6)));
        timelock.execute(900, address(counter), 0, data);
        vm.expectRevert(PayloadTimelock.NotQueued.selector);
        timelock.execute(900, address(counter), 0, data);
        vm.stopPrank();
        assertEq(counter.value(), 5);
    }

    function testHiddenVotingRules() public {
        vm.prank(attacker);
        vm.expectRevert(PayloadGovernor.NotVoter.selector);
        gov.propose(attacker, 1 ether, "");
        vm.prank(v1);
        uint256 id = gov.propose(grants, 1 ether, "");
        vm.prank(attacker);
        vm.expectRevert(PayloadGovernor.NotVoter.selector);
        gov.castVote(id, true);
        vm.prank(v1);
        gov.castVote(id, true);
        vm.prank(v1);
        vm.expectRevert(PayloadGovernor.AlreadyVoted.selector);
        gov.castVote(id, true);
        vm.expectRevert(PayloadGovernor.VotingOpen.selector);
        gov.queue(id);
        vm.warp(block.timestamp + 3 days);
        vm.prank(v2);
        vm.expectRevert(PayloadGovernor.VotingClosed.selector);
        gov.castVote(id, true);
        // One vote is below the quorum of two.
        vm.expectRevert(PayloadGovernor.ProposalDefeated.selector);
        gov.queue(id);
        vm.expectRevert(PayloadGovernor.NotQueued.selector);
        gov.execute(id, grants, 1 ether, "");
        vm.expectRevert(PayloadGovernor.UnknownProposal.selector);
        gov.queue(id + 1);
    }

    function testHiddenQueueOnceAndFailedCallReverts() public {
        bytes memory data = abi.encodeWithSelector(Counter.fail.selector);
        uint256 id = _passAndQueue(address(counter), 0, data);
        vm.expectRevert(PayloadGovernor.AlreadyQueued.selector);
        gov.queue(id);
        vm.expectRevert(PayloadTimelock.CallFailed.selector);
        gov.execute(id, address(counter), 0, data);
        assertTrue(timelock.etaOf(id) != 0);
    }
}
