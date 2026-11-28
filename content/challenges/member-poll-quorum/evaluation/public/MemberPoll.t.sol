// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MemberPoll.sol";

contract MemberPollTest is Test {
    MemberPoll public dao;
    address[] internal members;
    bytes32 constant TOPIC = keccak256("Adopt the new logo");

    function setUp() public {
        for (uint160 i = 1; i <= 5; i++) {
            members.push(address(0x1000 + i));
        }
        // 5 members, quorum of 3 votes, simple majority (more than or equal to 50.01%).
        dao = new MemberPoll(members, 3, 5001);
    }

    function _vote(uint256 pollId, uint256 memberIndex, bool support) internal {
        vm.prank(members[memberIndex]);
        dao.vote(pollId, support);
    }

    function _create(uint256 duration) internal returns (uint256 id) {
        vm.prank(members[0]);
        id = dao.createPoll(TOPIC, duration);
    }

    function testCreatePoll() public {
        uint256 id = _create(3 days);
        assertEq(id, 0);
        assertEq(dao.pollCount(), 1);

        (bytes32 topic, uint256 deadline, uint256 yes, uint256 no) = dao.getPoll(id);
        assertEq(topic, TOPIC);
        assertEq(deadline, block.timestamp + 3 days);
        assertEq(yes, 0);
        assertEq(no, 0);
        assertEq(uint256(dao.outcome(id)), uint256(MemberPoll.Outcome.Pending));
    }

    function testVotesAreCounted() public {
        uint256 id = _create(3 days);
        _vote(id, 0, true);
        _vote(id, 1, true);
        _vote(id, 2, false);

        (, , uint256 yes, uint256 no) = dao.getPoll(id);
        assertEq(yes, 2);
        assertEq(no, 1);
        assertTrue(dao.hasVoted(id, members[0]));
        assertFalse(dao.hasVoted(id, members[3]));
    }

    function testPollPasses() public {
        uint256 id = _create(3 days);
        _vote(id, 0, true);
        _vote(id, 1, true);
        _vote(id, 2, false);

        assertEq(uint256(dao.outcome(id)), uint256(MemberPoll.Outcome.Pending));
        vm.warp(block.timestamp + 3 days);
        assertEq(uint256(dao.outcome(id)), uint256(MemberPoll.Outcome.Passed));
    }

    function testPollRejected() public {
        uint256 id = _create(3 days);
        _vote(id, 0, true);
        _vote(id, 1, false);
        _vote(id, 2, false);

        vm.warp(block.timestamp + 3 days);
        assertEq(uint256(dao.outcome(id)), uint256(MemberPoll.Outcome.Rejected));
    }

    function testQuorumNotMet() public {
        uint256 id = _create(3 days);
        _vote(id, 0, true);
        _vote(id, 1, true);

        vm.warp(block.timestamp + 3 days);
        assertEq(uint256(dao.outcome(id)), uint256(MemberPoll.Outcome.QuorumNotMet));
    }

    function testCannotVoteTwice() public {
        uint256 id = _create(3 days);
        _vote(id, 0, true);

        vm.prank(members[0]);
        vm.expectRevert(MemberPoll.AlreadyVoted.selector);
        dao.vote(id, false);
    }
}
