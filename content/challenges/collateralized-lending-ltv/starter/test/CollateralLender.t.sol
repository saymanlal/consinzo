// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CollateralLender.sol";

contract MockERC20 {
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
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
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract CollateralLenderTest is Test {
    MockERC20 public coll;
    MockERC20 public debt;
    CollateralLender public lender;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        coll = new MockERC20();
        debt = new MockERC20();
        // 1 collateral token is worth 2000 debt tokens, 75% LTV
        lender = new CollateralLender(address(coll), address(debt), 2000 ether, 7500);
        debt.mint(address(lender), 100_000 ether);
        address[2] memory users = [alice, bob];
        for (uint256 i = 0; i < 2; i++) {
            coll.mint(users[i], 10 ether);
            vm.startPrank(users[i]);
            coll.approve(address(lender), type(uint256).max);
            debt.approve(address(lender), type(uint256).max);
            vm.stopPrank();
        }
    }

    function testLimitMath() public view {
        assertEq(lender.collateralValue(1 ether), 2000 ether);
        assertEq(lender.borrowLimit(1 ether), 1500 ether);
        assertEq(lender.borrowLimit(0.5 ether), 750 ether);
        assertEq(lender.maxBorrow(alice), 0);
    }

    function testDepositAndBorrow() public {
        vm.prank(alice);
        lender.depositCollateral(2 ether);
        assertEq(lender.maxBorrow(alice), 3000 ether);
        vm.prank(alice);
        lender.borrow(1000 ether);
        assertEq(debt.balanceOf(alice), 1000 ether);
        assertEq(lender.debtOf(alice), 1000 ether);
        assertEq(lender.availableToBorrow(alice), 2000 ether);
        assertEq(lender.totalDebt(), 1000 ether);
        assertEq(lender.totalCollateral(), 2 ether);
    }

    function testCannotBorrowAboveLimit() public {
        vm.prank(alice);
        lender.depositCollateral(1 ether);
        vm.prank(alice);
        vm.expectRevert(CollateralLender.ExceedsBorrowLimit.selector);
        lender.borrow(1500 ether + 1);
        vm.prank(alice);
        lender.borrow(1500 ether);
        assertEq(lender.availableToBorrow(alice), 0);
    }

    function testRepayThenWithdraw() public {
        vm.prank(alice);
        lender.depositCollateral(1 ether);
        vm.prank(alice);
        lender.borrow(1500 ether);
        vm.prank(alice);
        vm.expectRevert(CollateralLender.ExceedsBorrowLimit.selector);
        lender.withdrawCollateral(1);
        vm.prank(alice);
        uint256 paid = lender.repay(1500 ether);
        assertEq(paid, 1500 ether);
        vm.prank(alice);
        lender.withdrawCollateral(1 ether);
        assertEq(coll.balanceOf(alice), 10 ether);
        assertEq(lender.collateralOf(alice), 0);
        assertEq(lender.totalDebt(), 0);
    }

    function testPartialWithdrawWithinLimit() public {
        vm.prank(alice);
        lender.depositCollateral(2 ether);
        vm.prank(alice);
        lender.borrow(1500 ether);
        vm.prank(alice);
        lender.withdrawCollateral(1 ether);
        assertEq(lender.collateralOf(alice), 1 ether);
        assertEq(lender.availableToBorrow(alice), 0);
    }
}
