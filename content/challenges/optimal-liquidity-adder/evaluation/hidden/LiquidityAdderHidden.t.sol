// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LiquidityAdder.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    bool public returnFalse;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function setReturnFalse(bool value) external {
        returnFalse = value;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (returnFalse) return false;
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

/// Constant-product pair mock: mints for whatever it received since the last reserve update.
contract MockPair is IPair {
    address public override token0;
    address public override token1;
    uint112 internal reserve0;
    uint112 internal reserve1;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(address token0_, address token1_) {
        token0 = token0_;
        token1 = token1_;
    }

    function getReserves() external view override returns (uint112, uint112) {
        return (reserve0, reserve1);
    }

    /// Sets the reserves to the current balances without minting.
    function sync() public {
        reserve0 = uint112(MockERC20(token0).balanceOf(address(this)));
        reserve1 = uint112(MockERC20(token1).balanceOf(address(this)));
    }

    function mint(address to) external override returns (uint256 liquidity) {
        uint256 amount0 = MockERC20(token0).balanceOf(address(this)) - reserve0;
        uint256 amount1 = MockERC20(token1).balanceOf(address(this)) - reserve1;
        if (totalSupply == 0 || reserve0 == 0 || reserve1 == 0) {
            liquidity = _sqrt(amount0 * amount1);
        } else {
            uint256 l0 = (amount0 * totalSupply) / reserve0;
            uint256 l1 = (amount1 * totalSupply) / reserve1;
            liquidity = l0 < l1 ? l0 : l1;
        }
        require(liquidity > 0, "PAIR_ZERO_LIQUIDITY");
        totalSupply += liquidity;
        balanceOf[to] += liquidity;
        sync();
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

contract LiquidityAdderHiddenTest is Test {
    MockERC20 public t0;
    MockERC20 public t1;
    MockPair public pair;
    LiquidityAdder public adder;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        t0 = new MockERC20();
        t1 = new MockERC20();
        pair = new MockPair(address(t0), address(t1));
        adder = new LiquidityAdder();

        t0.mint(alice, 1_000_000 ether);
        t1.mint(alice, 1_000_000 ether);
        vm.startPrank(alice);
        t0.approve(address(adder), type(uint256).max);
        t1.approve(address(adder), type(uint256).max);
        vm.stopPrank();
    }

    /// Puts raw reserves into the pair without going through the helper.
    function _setReserves(uint256 r0, uint256 r1) internal {
        t0.mint(address(pair), r0);
        t1.mint(address(pair), r1);
        pair.sync();
    }

    function testHiddenQuoteReverts() public {
        vm.expectRevert(LiquidityAdder.InsufficientAmount.selector);
        adder.quote(0, 100, 100);
        vm.expectRevert(LiquidityAdder.InsufficientLiquidity.selector);
        adder.quote(1, 0, 100);
        vm.expectRevert(LiquidityAdder.InsufficientLiquidity.selector);
        adder.quote(1, 100, 0);
        // zero amount is reported before zero reserves
        vm.expectRevert(LiquidityAdder.InsufficientAmount.selector);
        adder.quote(0, 0, 0);
    }

    function testHiddenQuoteRoundsDownAndHandlesLargeValues() public view {
        assertEq(adder.quote(2, 3, 1), 0);
        assertEq(adder.quote(5, 3, 2), 3);
        uint256 big = uint256(type(uint112).max);
        assertEq(adder.quote(big, big, big), big);
    }

    function testHiddenRoundingWithSmallReserves() public {
        _setReserves(3, 10);

        (uint256 a0, uint256 a1) = adder.optimalAmounts(address(pair), 7, 100, 0, 0);
        assertEq(a0, 7);
        assertEq(a1, 23); // 7 * 10 / 3

        (a0, a1) = adder.optimalAmounts(address(pair), 7, 20, 0, 0);
        assertEq(a0, 6); // 20 * 3 / 10
        assertEq(a1, 20);

        // exactly matching: 23 <= 23 keeps the first branch
        (a0, a1) = adder.optimalAmounts(address(pair), 7, 23, 7, 23);
        assertEq(a0, 7);
        assertEq(a1, 23);
    }

    function testHiddenMinimumBoundaries() public {
        _setReserves(1_000 ether, 2_000 ether);

        // minimum equal to the optimal amount passes
        (uint256 a0, uint256 a1) = adder.optimalAmounts(address(pair), 100 ether, 300 ether, 100 ether, 200 ether);
        assertEq(a0, 100 ether);
        assertEq(a1, 200 ether);
        (a0, a1) = adder.optimalAmounts(address(pair), 100 ether, 150 ether, 75 ether, 150 ether);
        assertEq(a0, 75 ether);
        assertEq(a1, 150 ether);

        // one wei above fails with the error for the scaled-down side
        vm.expectRevert(LiquidityAdder.Insufficient1Amount.selector);
        adder.optimalAmounts(address(pair), 100 ether, 300 ether, 0, 200 ether + 1);
        vm.expectRevert(LiquidityAdder.Insufficient0Amount.selector);
        adder.optimalAmounts(address(pair), 100 ether, 150 ether, 75 ether + 1, 0);
    }

    function testHiddenOnlyScaledDownSideMinimumIsChecked() public {
        _setReserves(1_000 ether, 2_000 ether);
        // token0 is used in full, so only amount1Min is enforced in this branch
        (uint256 a0, uint256 a1) = adder.optimalAmounts(address(pair), 100 ether, 300 ether, 500 ether, 200 ether);
        assertEq(a0, 100 ether);
        assertEq(a1, 200 ether);
        // token1 is used in full, so only amount0Min is enforced in this branch
        (a0, a1) = adder.optimalAmounts(address(pair), 100 ether, 150 ether, 75 ether, 500 ether);
        assertEq(a0, 75 ether);
        assertEq(a1, 150 ether);
    }

    function testHiddenEmptyPoolIgnoresMinimums() public view {
        (uint256 a0, uint256 a1) = adder.optimalAmounts(address(pair), 5, 9, 1_000, 1_000);
        assertEq(a0, 5);
        assertEq(a1, 9);
    }

    function testHiddenOneSidedReserveReverts() public {
        t0.mint(address(pair), 500 ether);
        pair.sync(); // reserves (500, 0)
        vm.expectRevert(LiquidityAdder.InsufficientLiquidity.selector);
        adder.optimalAmounts(address(pair), 1 ether, 1 ether, 0, 0);

        vm.prank(alice);
        vm.expectRevert(LiquidityAdder.InsufficientLiquidity.selector);
        adder.addLiquidity(address(pair), 1 ether, 1 ether, 0, 0, alice, block.timestamp);
    }

    function testHiddenZeroDesiredAmountReverts() public {
        _setReserves(1_000 ether, 2_000 ether);
        vm.expectRevert(LiquidityAdder.InsufficientAmount.selector);
        adder.optimalAmounts(address(pair), 0, 1 ether, 0, 0);
    }

    function testHiddenDeadlineBoundaryAndOrder() public {
        uint256 deadline = block.timestamp + 100;
        vm.warp(deadline); // exactly at the deadline is still valid
        vm.prank(alice);
        (uint256 a0,,) = adder.addLiquidity(address(pair), 10 ether, 10 ether, 0, 0, alice, deadline);
        assertEq(a0, 10 ether);

        vm.warp(deadline + 1);
        vm.prank(alice);
        vm.expectRevert(LiquidityAdder.Expired.selector);
        adder.addLiquidity(address(pair), 10 ether, 10 ether, 0, 0, alice, deadline);

        // expiry is reported before the recipient check
        vm.prank(alice);
        vm.expectRevert(LiquidityAdder.Expired.selector);
        adder.addLiquidity(address(pair), 10 ether, 10 ether, 0, 0, address(0), deadline);
    }

    function testHiddenZeroRecipientReverts() public {
        vm.prank(alice);
        vm.expectRevert(LiquidityAdder.ZeroAddress.selector);
        adder.addLiquidity(address(pair), 10 ether, 10 ether, 0, 0, address(0), block.timestamp);
    }

    function testHiddenOnlyOptimalAmountsLeaveCallerAndHelperHoldsNothing() public {
        _setReserves(400 ether, 100 ether); // 4 token0 = 1 token1
        uint256 before0 = t0.balanceOf(alice);
        uint256 before1 = t1.balanceOf(alice);

        vm.prank(alice);
        (uint256 a0, uint256 a1, uint256 liq) =
            adder.addLiquidity(address(pair), 1_000 ether, 10 ether, 0, 0, bob, block.timestamp);
        assertEq(a0, 40 ether);
        assertEq(a1, 10 ether);

        assertEq(before0 - t0.balanceOf(alice), 40 ether);
        assertEq(before1 - t1.balanceOf(alice), 10 ether);
        assertEq(t0.balanceOf(address(pair)), 440 ether);
        assertEq(t1.balanceOf(address(pair)), 110 ether);
        assertEq(t0.balanceOf(address(adder)), 0);
        assertEq(t1.balanceOf(address(adder)), 0);

        // shares go to the recipient, not to the caller or the helper
        assertGt(liq, 0);
        assertEq(pair.balanceOf(bob), liq);
        assertEq(pair.balanceOf(alice), 0);
        assertEq(pair.balanceOf(address(adder)), 0);
    }

    function testHiddenRatioComesFromReservesNotBalances() public {
        _setReserves(1_000 ether, 1_000 ether);
        // donation that the pair has not accounted for yet: balances are 3:1, reserves 1:1
        t0.mint(address(pair), 2_000 ether);

        (uint256 a0, uint256 a1) = adder.optimalAmounts(address(pair), 50 ether, 80 ether, 0, 0);
        assertEq(a0, 50 ether);
        assertEq(a1, 50 ether);
    }

    function testHiddenFalseReturningTokenAbortsDeposit() public {
        _setReserves(1_000 ether, 1_000 ether);
        t1.setReturnFalse(true);
        vm.prank(alice);
        vm.expectRevert(LiquidityAdder.TransferFailed.selector);
        adder.addLiquidity(address(pair), 10 ether, 10 ether, 0, 0, alice, block.timestamp);

        t1.setReturnFalse(false);
        t0.setReturnFalse(true);
        vm.prank(alice);
        vm.expectRevert(LiquidityAdder.TransferFailed.selector);
        adder.addLiquidity(address(pair), 10 ether, 10 ether, 0, 0, alice, block.timestamp);

        // nothing moved in either attempt
        assertEq(t0.balanceOf(address(pair)), 1_000 ether);
        assertEq(t1.balanceOf(address(pair)), 1_000 ether);
        assertEq(pair.totalSupply(), 0);
    }

    function testHiddenSequentialDepositsKeepRatio() public {
        vm.prank(alice);
        (,, uint256 liq1) = adder.addLiquidity(address(pair), 300 ether, 700 ether, 0, 0, alice, block.timestamp);
        vm.prank(alice);
        (uint256 a0, uint256 a1, uint256 liq2) =
            adder.addLiquidity(address(pair), 30 ether, 1_000 ether, 30 ether, 70 ether, alice, block.timestamp);
        vm.prank(alice);
        (uint256 b0, uint256 b1,) =
            adder.addLiquidity(address(pair), 1_000 ether, 7 ether, 3 ether, 7 ether, alice, block.timestamp);

        assertEq(a0, 30 ether);
        assertEq(a1, 70 ether);
        assertEq(b0, 3 ether);
        assertEq(b1, 7 ether);
        // a deposit of 10% of the reserves mints 10% of the supply
        assertEq(liq2, liq1 / 10);
        assertEq(t0.balanceOf(address(pair)), 333 ether);
        assertEq(t1.balanceOf(address(pair)), 777 ether);
    }
}
