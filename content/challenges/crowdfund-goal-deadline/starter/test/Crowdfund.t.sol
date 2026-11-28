// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Crowdfund.sol";

contract CrowdfundTest is Test {
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

    function testConstructorSetsParameters() public view {
        assertEq(fund.creator(), creator);
        assertEq(fund.goal(), GOAL);
        assertEq(fund.deadline(), block.timestamp + DURATION);
        assertEq(fund.totalRaised(), 0);
        assertFalse(fund.claimed());
    }

    function testContributeRecordsAmounts() public {
        vm.prank(alice);
        fund.contribute{value: 3 ether}();
        vm.prank(bob);
        fund.contribute{value: 2 ether}();
        vm.prank(alice);
        fund.contribute{value: 1 ether}();

        assertEq(fund.contributions(alice), 4 ether);
        assertEq(fund.contributions(bob), 2 ether);
        assertEq(fund.totalRaised(), 6 ether);
        assertEq(address(fund).balance, 6 ether);
    }

    function testCreatorClaimsSuccessfulCampaign() public {
        vm.prank(alice);
        fund.contribute{value: 6 ether}();
        vm.prank(bob);
        fund.contribute{value: 5 ether}();

        vm.warp(fund.deadline());
        vm.prank(creator);
        fund.claim();

        assertTrue(fund.claimed());
        assertEq(creator.balance, 11 ether);
        assertEq(address(fund).balance, 0);
    }

    function testBackersRefundFailedCampaign() public {
        vm.prank(alice);
        fund.contribute{value: 4 ether}();
        vm.prank(bob);
        fund.contribute{value: 5 ether}();

        vm.warp(fund.deadline() + 1);
        vm.prank(alice);
        fund.refund();

        assertEq(alice.balance, 100 ether);
        assertEq(fund.contributions(alice), 0);
        assertEq(fund.contributions(bob), 5 ether);
        assertEq(address(fund).balance, 5 ether);
    }

    function testCannotClaimBeforeDeadline() public {
        vm.prank(alice);
        fund.contribute{value: 10 ether}();

        vm.prank(creator);
        vm.expectRevert(Crowdfund.CampaignActive.selector);
        fund.claim();
    }
}
