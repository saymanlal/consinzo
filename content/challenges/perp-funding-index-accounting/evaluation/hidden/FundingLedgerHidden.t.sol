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

contract FundingLedgerHiddenTest is Test {
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

    function testHiddenRoundingNeverCreatesMoney() public {
        _trade(alice, 3 ether);
        _trade(bob, -7 ether);
        ledger.setFundingRate(RATE);
        vm.warp(T0 + 100);
        // longs pay 3 in total; shorts earn floor(3e36 / 7e18) = 0.428571428571428571 per unit
        assertEq(ledger.pendingFunding(bob), -int256(2999999999999999997));
        ledger.settle(alice);
        ledger.settle(bob);
        assertEq(ledger.cumulativeFundingShort(), -int256(428571428571428571));
        assertEq(_margin(alice), 97 ether);
        assertEq(_margin(bob), 100 ether + 2999999999999999997);
        assertLe(_margin(alice) + _margin(bob) + _margin(carol), quote.balanceOf(address(ledger)));
    }

    function testHiddenPayerRoundsUp() public {
        _trade(alice, 1 ether + 1); // 1.000000000000000001 units
        _trade(bob, -1 ether);
        ledger.setFundingRate(1); // 1 wei of quote per unit per second
        vm.warp(T0 + 1);
        // owes (1e18 + 1) * 1 / 1e18 = 1.000...001 -> 2 ; total collected by the index is floor = 1
        assertEq(ledger.pendingFunding(alice), 2);
        assertEq(ledger.pendingFunding(bob), -1);
        ledger.settle(alice);
        ledger.settle(bob);
        assertEq(_margin(alice), 100 ether - 2);
        assertEq(_margin(bob), 100 ether + 1);
    }

    function testHiddenFlipFromLongToShort() public {
        _openThree();
        ledger.setFundingRate(RATE);
        vm.warp(T0 + 100);
        _trade(alice, -25 ether); // long 10 -> short 15, pays 10 first
        assertEq(_size(alice), -int256(15 ether));
        assertEq(_margin(alice), 90 ether);
        assertEq(ledger.longOpenInterest(), 0);
        assertEq(ledger.shortOpenInterest(), 35 ether);
        (, , int256 entry) = ledger.positions(alice);
        assertEq(entry, -int256(0.5 ether));
        // no longs left: nothing accrues
        vm.warp(T0 + 500);
        assertEq(ledger.pendingFunding(alice), 0);
        assertEq(ledger.pendingFunding(bob), -int256(2.5 ether));
    }

    function testHiddenRateChangeAccruesOldRateFirst() public {
        _openThree();
        ledger.setFundingRate(RATE);
        vm.warp(T0 + 100);
        ledger.setFundingRate(-RATE); // first 100 seconds stay at +RATE
        assertEq(ledger.cumulativeFundingLong(), int256(1 ether));
        vm.warp(T0 + 150);
        // 50 seconds of shorts paying 0.5 per unit: 10 in total, 1 per long unit
        (int256 l, int256 s) = ledger.currentIndices();
        assertEq(l, 0);
        assertEq(s, 0);
        assertEq(ledger.pendingFunding(alice), 0);
        assertEq(ledger.pendingFunding(bob), 0);
        vm.prank(alice);
        vm.expectRevert(FundingLedger.NotOwner.selector);
        ledger.setFundingRate(0);
    }

    function testHiddenViewsMatchSettlementWithoutAccrue() public {
        _openThree();
        ledger.setFundingRate(RATE);
        vm.warp(T0 + 37);
        (int256 l, int256 s) = ledger.currentIndices();
        assertEq(l, int256(0.37 ether));
        assertEq(s, -int256(0.185 ether));
        // stored values are still stale
        assertEq(ledger.cumulativeFundingLong(), 0);
        int256 pendingCarol = ledger.pendingFunding(carol);
        assertEq(pendingCarol, -int256(2.775 ether));
        ledger.settle(carol);
        assertEq(_margin(carol), 102.775 ether);
        // settling again in the same block is a no-op
        ledger.settle(carol);
        assertEq(_margin(carol), 102.775 ether);
    }

    function testHiddenLateJoinerGetsNoPastFunding() public {
        _trade(alice, 10 ether);
        _trade(bob, -10 ether);
        ledger.setFundingRate(RATE);
        vm.warp(T0 + 100);
        _trade(carol, -10 ether);
        assertEq(ledger.pendingFunding(carol), 0);
        vm.warp(T0 + 200);
        // period two: longs pay 10 over 20 short units
        ledger.settle(alice);
        ledger.settle(bob);
        ledger.settle(carol);
        assertEq(_margin(alice), 80 ether);
        assertEq(_margin(bob), 115 ether);
        assertEq(_margin(carol), 105 ether);
    }

    function testHiddenShortfallWhenMarginRunsOut() public {
        _fund(dave, 10 ether);
        _trade(dave, 10 ether);
        _trade(bob, -10 ether);
        ledger.setFundingRate(RATE);
        vm.warp(T0 + 200);
        assertEq(ledger.pendingFunding(dave), int256(20 ether));
        ledger.settle(dave);
        ledger.settle(bob);
        assertEq(_margin(dave), 0);
        assertEq(ledger.shortfall(), 10 ether);
        assertEq(_margin(bob), 120 ether);
        vm.prank(dave);
        vm.expectRevert(FundingLedger.InsufficientMargin.selector);
        ledger.withdraw(1);
        // dave may still close; a flat position needs no margin
        _trade(dave, -10 ether);
        assertEq(ledger.longOpenInterest(), 0);
        assertEq(ledger.shortfall(), 10 ether);
    }

    function testHiddenDepositAndWithdrawSettleFirst() public {
        _openThree();
        ledger.setFundingRate(RATE);
        vm.warp(T0 + 100);
        quote.mint(alice, 5 ether);
        vm.prank(alice);
        ledger.deposit(5 ether);
        assertEq(_margin(alice), 95 ether);
        assertEq(ledger.pendingFunding(alice), 0);
        vm.prank(bob);
        ledger.withdraw(97.5 ether); // 102.5 after funding, 5 must stay for 5 units
        assertEq(_margin(bob), 5 ether);
        assertEq(quote.balanceOf(bob), 97.5 ether);
        vm.prank(bob);
        vm.expectRevert(FundingLedger.InsufficientMargin.selector);
        ledger.withdraw(1);
    }

    function testHiddenCloseAndWithdrawEverything() public {
        _openThree();
        ledger.setFundingRate(RATE);
        vm.warp(T0 + 100);
        _trade(alice, -10 ether);
        _trade(bob, 5 ether);
        _trade(carol, 15 ether);
        assertEq(ledger.longOpenInterest(), 0);
        assertEq(ledger.shortOpenInterest(), 0);
        vm.prank(alice);
        ledger.withdraw(90 ether);
        vm.prank(bob);
        ledger.withdraw(102.5 ether);
        vm.prank(carol);
        ledger.withdraw(107.5 ether);
        assertEq(quote.balanceOf(address(ledger)), 0);
        (int256 size, uint256 margin, int256 entry) = ledger.positions(alice);
        assertEq(size, 0);
        assertEq(margin, 0);
        assertEq(entry, 0);
    }

    function testHiddenFundingDirectionReversesOverTime() public {
        _trade(alice, 10 ether);
        _trade(bob, -10 ether);
        ledger.setFundingRate(RATE);
        vm.warp(T0 + 100);
        ledger.setFundingRate(-3 * RATE);
        vm.warp(T0 + 200);
        // +10 then -30 for alice
        assertEq(ledger.pendingFunding(alice), -int256(20 ether));
        assertEq(ledger.pendingFunding(bob), int256(20 ether));
        ledger.settle(bob);
        assertEq(_margin(bob), 80 ether);
    }

    function testHiddenInputValidation() public {
        vm.startPrank(alice);
        vm.expectRevert(FundingLedger.ZeroAmount.selector);
        ledger.deposit(0);
        vm.expectRevert(FundingLedger.ZeroAmount.selector);
        ledger.withdraw(0);
        vm.expectRevert(FundingLedger.ZeroAmount.selector);
        ledger.modifyPosition(0);
        vm.expectRevert(FundingLedger.InsufficientMargin.selector);
        ledger.withdraw(100 ether + 1);
        vm.expectRevert(FundingLedger.InsufficientMargin.selector);
        ledger.modifyPosition(-int256(100 ether) - 1);
        ledger.modifyPosition(-int256(100 ether));
        vm.stopPrank();
        assertEq(ledger.shortOpenInterest(), 100 ether);
    }
}
