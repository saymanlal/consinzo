// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FundingLedger.sol";

contract MockERC20 {
    string public name;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory name_) {
        name = name_;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function burn(address from, uint256 amount) external {
        totalSupply -= amount;
        balanceOf[from] -= amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract FundingLedgerTest is Test {
    FundingLedger public ledger;
    MockERC20 public quote;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA201);
    address public dave = address(0xDA7E);
    uint256 internal constant T0 = 1_700_000_000;
    int256 internal constant RATE = 0.01 ether; // 1 quote per unit per 100 seconds

    function setUp() public {
        quote = new MockERC20("QUOTE");
        ledger = new FundingLedger(IQuoteToken(address(quote)), 1 ether);
        _fund(alice, 100 ether);
        _fund(bob, 100 ether);
        _fund(carol, 100 ether);
    }

    function _fund(address who, uint256 amount) internal {
        quote.mint(who, amount);
        vm.prank(who);
        quote.approve(address(ledger), type(uint256).max);
        vm.prank(who);
        ledger.deposit(amount);
    }

    function _trade(address who, int256 delta) internal {
        vm.prank(who);
        ledger.modifyPosition(delta);
    }

    function _margin(address who) internal view returns (uint256 m) {
        (, m, ) = ledger.positions(who);
    }

    function _size(address who) internal view returns (int256 s) {
        (s, , ) = ledger.positions(who);
    }

    /// alice long 10, bob short 5, carol short 15
    function _openThree() internal {
        _trade(alice, 10 ether);
        _trade(bob, -5 ether);
        _trade(carol, -15 ether);
    }

    function testOpenInterestTracksBothSides() public {
        _openThree();
        assertEq(ledger.longOpenInterest(), 10 ether);
        assertEq(ledger.shortOpenInterest(), 20 ether);
        assertEq(_size(alice), int256(10 ether));
        assertEq(_size(carol), -int256(15 ether));
        assertEq(_margin(alice), 100 ether);
        assertEq(quote.balanceOf(address(ledger)), 300 ether);
    }

    function testPositiveRateLongsPayShorts() public {
        _openThree();
        ledger.setFundingRate(RATE);
        vm.warp(T0 + 100);
        // longs pay 1 per unit = 10 in total, spread over 20 units of shorts
        assertEq(ledger.pendingFunding(alice), int256(10 ether));
        assertEq(ledger.pendingFunding(bob), -int256(2.5 ether));
        assertEq(ledger.pendingFunding(carol), -int256(7.5 ether));
        ledger.settle(alice);
        ledger.settle(bob);
        ledger.settle(carol);
        assertEq(_margin(alice), 90 ether);
        assertEq(_margin(bob), 102.5 ether);
        assertEq(_margin(carol), 107.5 ether);
        assertEq(ledger.cumulativeFundingLong(), int256(1 ether));
        assertEq(ledger.cumulativeFundingShort(), -int256(0.5 ether));
        assertEq(ledger.pendingFunding(alice), 0);
    }

    function testNegativeRateShortsPayLongs() public {
        _openThree();
        ledger.setFundingRate(-RATE);
        vm.warp(T0 + 100);
        // shorts pay 1 per unit = 20 in total, longs receive 2 per unit
        ledger.settle(alice);
        ledger.settle(bob);
        ledger.settle(carol);
        assertEq(_margin(alice), 120 ether);
        assertEq(_margin(bob), 95 ether);
        assertEq(_margin(carol), 85 ether);
        assertEq(ledger.cumulativeFundingLong(), -int256(2 ether));
        assertEq(ledger.cumulativeFundingShort(), int256(1 ether));
    }

    function testNoFundingWhenOneSideIsEmpty() public {
        _trade(alice, 10 ether);
        ledger.setFundingRate(RATE);
        vm.warp(T0 + 100);
        assertEq(ledger.pendingFunding(alice), 0);
        ledger.accrue();
        assertEq(ledger.lastAccrual(), T0 + 100);
        assertEq(ledger.cumulativeFundingLong(), 0);
        // the empty period is not charged retroactively once a short appears
        _trade(bob, -10 ether);
        vm.warp(T0 + 200);
        assertEq(ledger.pendingFunding(alice), int256(10 ether));
        assertEq(ledger.pendingFunding(bob), -int256(10 ether));
    }

    function testModifyPositionSettlesAtOldSize() public {
        _openThree();
        ledger.setFundingRate(RATE);
        vm.warp(T0 + 100);
        _trade(alice, 10 ether); // pays 10 for the first period, then holds 20
        assertEq(_margin(alice), 90 ether);
        assertEq(ledger.longOpenInterest(), 20 ether);
        vm.warp(T0 + 200);
        ledger.settle(alice);
        ledger.settle(bob);
        ledger.settle(carol);
        // second period: longs pay 20, shorts receive 1 per unit; bob and carol also collect period one
        assertEq(_margin(alice), 70 ether);
        assertEq(_margin(bob), 107.5 ether);
        assertEq(_margin(carol), 122.5 ether);
    }

    function testMarginRequirement() public {
        _trade(alice, 10 ether);
        vm.prank(alice);
        vm.expectRevert(FundingLedger.InsufficientMargin.selector);
        ledger.withdraw(90 ether + 1);
        vm.prank(alice);
        ledger.withdraw(90 ether);
        assertEq(quote.balanceOf(alice), 90 ether);
        vm.prank(alice);
        vm.expectRevert(FundingLedger.InsufficientMargin.selector);
        ledger.modifyPosition(1);
    }
}
