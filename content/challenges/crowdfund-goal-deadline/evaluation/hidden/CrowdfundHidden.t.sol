// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Crowdfund.sol";

contract ReentrantBacker {
    Crowdfund public fund;
    uint256 public attempts;

    constructor(Crowdfund _fund) payable {
        fund = _fund;
    }

    function back() external {
        fund.contribute{value: address(this).balance}();
    }

    function pull() external {
        fund.refund();
    }

    receive() external payable {
        if (attempts == 0) {
            attempts = 1;
            // A second refund must find nothing; swallow the failure so the first one completes.
            try fund.refund() {} catch {}
        }
    }
}

contract CrowdfundHiddenTest is Test {
    Crowdfund public fund;
    address public creator = address(0xC0FFEE);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    uint256 constant GOAL = 10 ether;
    uint256 constant DURATION = 7 days;

    function setUp() public {
        vm.prank(creator);
        fund = new Crowdfund(GOAL, DURATION);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    function testHiddenContributeAtDeadlineReverts() public {
        vm.warp(fund.deadline() - 1);
        vm.prank(alice);
        fund.contribute{value: 1 ether}();

        vm.warp(fund.deadline());
        vm.prank(alice);
        vm.expectRevert(Crowdfund.CampaignEnded.selector);
        fund.contribute{value: 1 ether}();
        assertEq(fund.totalRaised(), 1 ether);
    }

    function testHiddenZeroContributionReverts() public {
        vm.prank(alice);
        vm.expectRevert(Crowdfund.ZeroAmount.selector);
        fund.contribute{value: 0}();
    }

    function testHiddenOnlyCreatorClaims() public {
        vm.prank(alice);
        fund.contribute{value: 12 ether}();
        vm.warp(fund.deadline());

        vm.prank(alice);
        vm.expectRevert(Crowdfund.NotCreator.selector);
        fund.claim();
        assertEq(address(fund).balance, 12 ether);
    }

    function testHiddenClaimRequiresGoal() public {
        vm.prank(alice);
        fund.contribute{value: GOAL - 1}();
        vm.warp(fund.deadline());

        vm.prank(creator);
        vm.expectRevert(Crowdfund.GoalNotReached.selector);
        fund.claim();
    }

    function testHiddenExactGoalSucceedsAndBlocksRefund() public {
        vm.prank(alice);
        fund.contribute{value: GOAL}();
        vm.warp(fund.deadline());

        vm.prank(alice);
        vm.expectRevert(Crowdfund.GoalWasReached.selector);
        fund.refund();

        vm.prank(creator);
        fund.claim();
        assertEq(creator.balance, GOAL);
    }

    function testHiddenDoubleClaimReverts() public {
        vm.prank(alice);
        fund.contribute{value: 15 ether}();
        vm.warp(fund.deadline() + 1 days);

        vm.prank(creator);
        fund.claim();
        vm.prank(creator);
        vm.expectRevert(Crowdfund.AlreadyClaimed.selector);
        fund.claim();
        assertEq(creator.balance, 15 ether);
    }

    function testHiddenRefundBeforeDeadlineReverts() public {
        vm.prank(alice);
        fund.contribute{value: 1 ether}();
        vm.warp(fund.deadline() - 1);

        vm.prank(alice);
        vm.expectRevert(Crowdfund.CampaignActive.selector);
        fund.refund();
    }

    function testHiddenDoubleRefundAndStrangerRefundRevert() public {
        vm.prank(alice);
        fund.contribute{value: 2 ether}();
        vm.prank(bob);
        fund.contribute{value: 3 ether}();
        vm.warp(fund.deadline());

        vm.prank(alice);
        fund.refund();
        vm.prank(alice);
        vm.expectRevert(Crowdfund.NothingToRefund.selector);
        fund.refund();

        vm.prank(creator);
        vm.expectRevert(Crowdfund.NothingToRefund.selector);
        fund.refund();

        // Bob's money is untouched and totalRaised stays a historical total.
        assertEq(address(fund).balance, 3 ether);
        assertEq(fund.totalRaised(), 5 ether);
        vm.prank(bob);
        fund.refund();
        assertEq(bob.balance, 100 ether);
        assertEq(address(fund).balance, 0);
    }

    function testHiddenReentrantRefundCannotDrain() public {
        ReentrantBacker attacker = new ReentrantBacker{value: 2 ether}(fund);
        attacker.back();
        vm.prank(alice);
        fund.contribute{value: 5 ether}();
        vm.warp(fund.deadline());

        attacker.pull();

        assertEq(attacker.attempts(), 1);
        assertEq(address(attacker).balance, 2 ether);
        assertEq(address(fund).balance, 5 ether);
    }
}
