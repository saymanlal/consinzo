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

contract CollateralLenderHiddenTest is Test {
    MockERC20 public coll;
    MockERC20 public debt;
    CollateralLender public lender;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        coll = new MockERC20();
        debt = new MockERC20();
        lender = new CollateralLender(address(coll), address(debt), 2000 ether, 7500);
        debt.mint(address(lender), 5_000 ether);
        address[2] memory users = [alice, bob];
        for (uint256 i = 0; i < 2; i++) {
            coll.mint(users[i], 10 ether);
            vm.startPrank(users[i]);
            coll.approve(address(lender), type(uint256).max);
            debt.approve(address(lender), type(uint256).max);
            vm.stopPrank();
        }
    }

    function testHiddenWithdrawBoundaryWithDebt() public {
        vm.prank(alice);
        lender.depositCollateral(1 ether);
        vm.prank(alice);
        lender.borrow(1000 ether);
        // 1000 debt needs at least 0.666666666666666667 collateral to stay locked
        vm.prank(alice);
        vm.expectRevert(CollateralLender.ExceedsBorrowLimit.selector);
        lender.withdrawCollateral(333333333333333334);
        vm.prank(alice);
        lender.withdrawCollateral(333333333333333333);
        assertEq(lender.collateralOf(alice), 666666666666666667);
        // the last wei of collateral backs 1500 wei of debt, of which 500 are unused
        assertEq(lender.availableToBorrow(alice), 500);
        vm.prank(alice);
        vm.expectRevert(CollateralLender.ExceedsBorrowLimit.selector);
        lender.withdrawCollateral(1);
        vm.prank(alice);
        vm.expectRevert(CollateralLender.ExceedsBorrowLimit.selector);
        lender.borrow(501);
        vm.prank(alice);
        lender.borrow(500);
    }

    function testHiddenDustRoundsAgainstBorrower() public {
        CollateralLender odd = new CollateralLender(address(coll), address(debt), 1.5 ether, 7500);
        debt.mint(address(odd), 1000);
        vm.prank(alice);
        coll.approve(address(odd), type(uint256).max);
        vm.prank(alice);
        odd.depositCollateral(1);
        // value floor(1.5) = 1, limit floor(0.75) = 0
        assertEq(odd.collateralValue(1), 1);
        assertEq(odd.maxBorrow(alice), 0);
        vm.prank(alice);
        vm.expectRevert(CollateralLender.ExceedsBorrowLimit.selector);
        odd.borrow(1);
        vm.prank(alice);
        odd.depositCollateral(2);
        // 3 wei: value floor(4.5) = 4, limit 3
        assertEq(odd.maxBorrow(alice), 3);
        vm.prank(alice);
        odd.borrow(3);
        vm.prank(alice);
        vm.expectRevert(CollateralLender.ExceedsBorrowLimit.selector);
        odd.withdrawCollateral(1);
    }

    function testHiddenRepayIsCapped() public {
        vm.prank(alice);
        lender.depositCollateral(1 ether);
        vm.prank(alice);
        lender.borrow(400 ether);
        debt.mint(alice, 1000 ether);
        vm.prank(alice);
        assertEq(lender.repay(100 ether), 100 ether);
        vm.prank(alice);
        assertEq(lender.repay(5000 ether), 300 ether);
        assertEq(lender.debtOf(alice), 0);
        assertEq(lender.totalDebt(), 0);
        assertEq(debt.balanceOf(alice), 1000 ether);
        assertEq(debt.balanceOf(address(lender)), 5_000 ether);
        vm.prank(alice);
        vm.expectRevert(CollateralLender.NoDebt.selector);
        lender.repay(1);
    }

    function testHiddenBorrowersAreIsolated() public {
        vm.prank(alice);
        lender.depositCollateral(4 ether);
        vm.prank(bob);
        vm.expectRevert(CollateralLender.ExceedsBorrowLimit.selector);
        lender.borrow(1);
        vm.prank(bob);
        vm.expectRevert(CollateralLender.InsufficientCollateral.selector);
        lender.withdrawCollateral(1);
        vm.prank(bob);
        lender.depositCollateral(1 ether);
        vm.prank(bob);
        lender.borrow(1500 ether);
        vm.prank(alice);
        lender.borrow(2000 ether);
        assertEq(lender.totalDebt(), 3500 ether);
        assertEq(lender.totalCollateral(), 5 ether);
        // bob repaying does not touch alice
        vm.prank(bob);
        lender.repay(1500 ether);
        assertEq(lender.debtOf(alice), 2000 ether);
        vm.prank(bob);
        lender.withdrawCollateral(1 ether);
        assertEq(coll.balanceOf(address(lender)), 4 ether);
        assertEq(lender.totalCollateral(), 4 ether);
    }

    function testHiddenLiquidityLimitAndOrder() public {
        vm.prank(alice);
        lender.depositCollateral(4 ether); // limit 6000, pool holds 5000
        vm.prank(alice);
        vm.expectRevert(CollateralLender.InsufficientLiquidity.selector);
        lender.borrow(5_000 ether + 1);
        // above both: the limit error is reported first
        vm.prank(alice);
        vm.expectRevert(CollateralLender.ExceedsBorrowLimit.selector);
        lender.borrow(6_000 ether + 1);
        vm.prank(alice);
        lender.borrow(5_000 ether);
        assertEq(debt.balanceOf(address(lender)), 0);
        assertEq(lender.availableToBorrow(alice), 1_000 ether);
        // repaid tokens become lendable again
        vm.prank(alice);
        lender.repay(200 ether);
        vm.prank(alice);
        lender.borrow(200 ether);
        assertEq(lender.debtOf(alice), 5_000 ether);
    }

    function testHiddenZeroAmountsAndOverWithdraw() public {
        vm.startPrank(alice);
        vm.expectRevert(CollateralLender.ZeroAmount.selector);
        lender.depositCollateral(0);
        vm.expectRevert(CollateralLender.ZeroAmount.selector);
        lender.borrow(0);
        vm.expectRevert(CollateralLender.ZeroAmount.selector);
        lender.repay(0);
        vm.expectRevert(CollateralLender.ZeroAmount.selector);
        lender.withdrawCollateral(0);
        lender.depositCollateral(1 ether);
        vm.expectRevert(CollateralLender.InsufficientCollateral.selector);
        lender.withdrawCollateral(1 ether + 1);
        lender.withdrawCollateral(1 ether);
        vm.stopPrank();
        assertEq(coll.balanceOf(alice), 10 ether);
    }
}
