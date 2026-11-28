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

contract PayloadGovernorTest is GovFixture {
    function setUp() public {
        _deploy();
    }

    function testSubstitutedPayloadCannotDrainTreasury() public {
        uint256 id = _passAndQueue(grants, 1 ether, "");
        vm.prank(attacker);
        vm.expectRevert(PayloadGovernor.PayloadMismatch.selector);
        gov.execute(id, attacker, 100 ether, "");
        assertEq(address(timelock).balance, 100 ether);
        assertEq(attacker.balance, 0);
    }

    function testVotedPayloadExecutesOnce() public {
        uint256 id = _passAndQueue(grants, 1 ether, "");
        vm.prank(attacker); // execution is permissionless
        gov.execute(id, grants, 1 ether, "");
        assertEq(grants.balance, 1 ether);
        assertEq(address(timelock).balance, 99 ether);
        vm.expectRevert(PayloadGovernor.AlreadyExecuted.selector);
        gov.execute(id, grants, 1 ether, "");
    }

    function testProposalCommitsToPayloadHash() public {
        bytes memory data = abi.encodeWithSelector(Counter.set.selector, uint256(42));
        vm.prank(v1);
        uint256 id = gov.propose(address(counter), 0, data);
        assertEq(gov.payloadHashOf(id), keccak256(abi.encode(address(counter), uint256(0), data)));
    }

    function testTimelockRejectsMismatchEvenFromGovernor() public {
        bytes32 h = gov.hashPayload(grants, 1 ether, "");
        vm.prank(address(gov));
        timelock.queue(77, h);
        vm.warp(block.timestamp + 2 days);
        vm.prank(address(gov));
        vm.expectRevert(PayloadTimelock.PayloadMismatch.selector);
        timelock.execute(77, attacker, 1 ether, "");
        vm.prank(address(gov));
        timelock.execute(77, grants, 1 ether, "");
        assertEq(grants.balance, 1 ether);
    }

    function testExecuteBeforeEtaReverts() public {
        vm.prank(v1);
        uint256 id = gov.propose(grants, 1 ether, "");
        vm.prank(v1);
        gov.castVote(id, true);
        vm.prank(v2);
        gov.castVote(id, true);
        vm.warp(block.timestamp + 3 days);
        gov.queue(id);
        vm.expectRevert(PayloadTimelock.NotReady.selector);
        gov.execute(id, grants, 1 ether, "");
    }
}
