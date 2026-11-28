// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MemberPoll.sol";

contract MemberPollHiddenTest is Test {
    address[] internal members;
    address internal outsider = address(0xBAD);
    bytes32 constant TOPIC = keccak256("Raise the membership fee");

    function setUp() public {
        for (uint160 i = 1; i <= 10; i++) {
            members.push(address(0x2000 + i));
        }
    }

    function _deploy(uint256 quorum, uint256 thresholdBps) internal returns (MemberPoll) {
        return new MemberPoll(members, quorum, thresholdBps);
    }

    function _create(MemberPoll dao, uint256 duration) internal returns (uint256 id) {
        vm.prank(members[9]);
        id = dao.createPoll(TOPIC, duration);
    }

    /// Members [0, yes) vote yes and members [yes, yes + no) vote no.
    function _cast(MemberPoll dao, uint256 id, uint256 yes, uint256 no) internal {
        for (uint256 i = 0; i < yes + no; i++) {
            vm.prank(members[i]);
            dao.vote(id, i < yes);
        }
    }

    function _outcomeAfter(MemberPoll dao, uint256 id) internal returns (uint256) {
        (, uint256 deadline, , ) = dao.getPoll(id);
        vm.warp(deadline);
        return uint256(dao.outcome(id));
    }

    function testHiddenOutsiderCannotCreateOrVote() public {
        MemberPoll dao = _deploy(3, 5000);
        vm.prank(outsider);
        vm.expectRevert(MemberPoll.NotMember.selector);
        dao.createPoll(TOPIC, 1 days);
        assertEq(dao.pollCount(), 0);

        uint256 id = _create(dao, 1 days);
        vm.prank(outsider);
        vm.expectRevert(MemberPoll.NotMember.selector);
        dao.vote(id, true);

        // The deployer is not a member either.
        vm.expectRevert(MemberPoll.NotMember.selector);
        dao.vote(id, true);
    }

    function testHiddenZeroDurationReverts() public {
        MemberPoll dao = _deploy(3, 5000);
        vm.prank(members[0]);
        vm.expectRevert(MemberPoll.InvalidDuration.selector);
        dao.createPoll(TOPIC, 0);
    }

    function testHiddenUnknownPollReverts() public {
        MemberPoll dao = _deploy(3, 5000);
        vm.prank(members[0]);
        vm.expectRevert(MemberPoll.UnknownPoll.selector);
        dao.vote(0, true);

        _create(dao, 1 days);
        vm.prank(members[0]);
        vm.expectRevert(MemberPoll.UnknownPoll.selector);
        dao.vote(1, true);

        vm.expectRevert(MemberPoll.UnknownPoll.selector);
        dao.outcome(1);
        vm.expectRevert(MemberPoll.UnknownPoll.selector);
        dao.getPoll(1);
    }

    function testHiddenDeadlineBoundary() public {
        MemberPoll dao = _deploy(1, 5000);
        uint256 id = _create(dao, 1 days);
        uint256 deadline = block.timestamp + 1 days;

        vm.warp(deadline - 1);
        vm.prank(members[0]);
        dao.vote(id, true);
        assertEq(uint256(dao.outcome(id)), uint256(MemberPoll.Outcome.Pending));

        vm.warp(deadline);
        vm.prank(members[1]);
        vm.expectRevert(MemberPoll.VotingClosed.selector);
        dao.vote(id, false);
        assertEq(uint256(dao.outcome(id)), uint256(MemberPoll.Outcome.Passed));
    }

    function testHiddenVoteCannotBeChangedOrRepeated() public {
        MemberPoll dao = _deploy(1, 5000);
        uint256 id = _create(dao, 1 days);
        vm.prank(members[0]);
        dao.vote(id, false);

        vm.prank(members[0]);
        vm.expectRevert(MemberPoll.AlreadyVoted.selector);
        dao.vote(id, true);
        vm.prank(members[0]);
        vm.expectRevert(MemberPoll.AlreadyVoted.selector);
        dao.vote(id, false);

        (, , uint256 yes, uint256 no) = dao.getPoll(id);
        assertEq(yes, 0);
        assertEq(no, 1);
    }

    function testHiddenQuorumBoundary() public {
        MemberPoll dao = _deploy(6, 5000);
        uint256 a = _create(dao, 1 days);
        uint256 b = _create(dao, 1 days);
        _cast(dao, a, 5, 0); // unanimous but one vote short of quorum
        _cast(dao, b, 3, 3); // quorum exactly met, 50% yes

        assertEq(_outcomeAfter(dao, a), uint256(MemberPoll.Outcome.QuorumNotMet));
        assertEq(uint256(dao.outcome(b)), uint256(MemberPoll.Outcome.Passed));
    }

    function testHiddenNoVotesCountTowardsQuorum() public {
        MemberPoll dao = _deploy(4, 5000);
        uint256 id = _create(dao, 1 days);
        _cast(dao, id, 0, 4);
        assertEq(_outcomeAfter(dao, id), uint256(MemberPoll.Outcome.Rejected));
    }

    function testHiddenSupermajorityThreshold() public {
        // Two thirds, rounded up to 6667 bps: 7 of 10 passes, 6 of 9 fails (66.66%), 6 of 10 fails.
        MemberPoll dao = _deploy(3, 6667);
        uint256 a = _create(dao, 1 days);
        uint256 b = _create(dao, 1 days);
        uint256 c = _create(dao, 1 days);
        _cast(dao, a, 7, 3);
        _cast(dao, b, 6, 3);
        _cast(dao, c, 6, 4);

        assertEq(_outcomeAfter(dao, a), uint256(MemberPoll.Outcome.Passed));
        assertEq(uint256(dao.outcome(b)), uint256(MemberPoll.Outcome.Rejected));
        assertEq(uint256(dao.outcome(c)), uint256(MemberPoll.Outcome.Rejected));
    }

    function testHiddenThresholdNeedsNoRoundingLuck() public {
        // 3334 bps of 3 votes is 1.0002 votes: one yes out of three must not pass.
        MemberPoll dao = _deploy(3, 3334);
        uint256 a = _create(dao, 1 days);
        uint256 b = _create(dao, 1 days);
        _cast(dao, a, 1, 2);
        _cast(dao, b, 2, 1);
        assertEq(_outcomeAfter(dao, a), uint256(MemberPoll.Outcome.Rejected));
        assertEq(uint256(dao.outcome(b)), uint256(MemberPoll.Outcome.Passed));
    }

    function testHiddenUnanimityThreshold() public {
        MemberPoll dao = _deploy(2, 10000);
        uint256 a = _create(dao, 1 days);
        uint256 b = _create(dao, 1 days);
        _cast(dao, a, 10, 0);
        _cast(dao, b, 9, 1);
        assertEq(_outcomeAfter(dao, a), uint256(MemberPoll.Outcome.Passed));
        assertEq(uint256(dao.outcome(b)), uint256(MemberPoll.Outcome.Rejected));
    }

    function testHiddenPollsAreIndependent() public {
        MemberPoll dao = _deploy(2, 5000);
        uint256 a = _create(dao, 1 days);
        uint256 b = _create(dao, 5 days);
        assertEq(a, 0);
        assertEq(b, 1);
        _cast(dao, a, 2, 0);

        // Voting in poll a does not mark the member as having voted in poll b.
        assertFalse(dao.hasVoted(b, members[0]));
        vm.warp(block.timestamp + 1 days);
        assertEq(uint256(dao.outcome(a)), uint256(MemberPoll.Outcome.Passed));
        assertEq(uint256(dao.outcome(b)), uint256(MemberPoll.Outcome.Pending));

        _cast(dao, b, 0, 2);
        vm.warp(block.timestamp + 4 days);
        assertEq(uint256(dao.outcome(b)), uint256(MemberPoll.Outcome.Rejected));
        assertEq(uint256(dao.outcome(a)), uint256(MemberPoll.Outcome.Passed));
    }

    function testHiddenConstructorRejectsBadConfig() public {
        vm.expectRevert(MemberPoll.InvalidConfig.selector);
        new MemberPoll(members, 11, 5000);
    }
}
