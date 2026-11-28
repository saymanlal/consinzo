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

contract LiquidityAdderTest is Test {
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

        t0.mint(alice, 10_000 ether);
        t1.mint(alice, 10_000 ether);
        vm.startPrank(alice);
        t0.approve(address(adder), type(uint256).max);
        t1.approve(address(adder), type(uint256).max);
        vm.stopPrank();
    }

    function _seed() internal {
        // 1 token0 = 2 token1
        vm.prank(alice);
        adder.addLiquidity(address(pair), 1_000 ether, 2_000 ether, 0, 0, alice, block.timestamp);
    }

    function testQuote() public view {
        assertEq(adder.quote(100, 1_000, 2_000), 200);
        assertEq(adder.quote(1, 3, 10), 3);
    }

    function testFirstDepositUsesDesiredAmounts() public {
        vm.prank(alice);
        (uint256 a0, uint256 a1, uint256 liq) =
            adder.addLiquidity(address(pair), 1_000 ether, 2_000 ether, 0, 0, bob, block.timestamp);
        assertEq(a0, 1_000 ether);
        assertEq(a1, 2_000 ether);
        assertGt(liq, 0);
        assertEq(pair.balanceOf(bob), liq);
        assertEq(t0.balanceOf(address(pair)), 1_000 ether);
        assertEq(t1.balanceOf(address(pair)), 2_000 ether);
    }

    function testToken0IsFullyUsedWhenToken1IsInExcess() public {
        _seed();
        vm.prank(alice);
        (uint256 a0, uint256 a1,) =
            adder.addLiquidity(address(pair), 100 ether, 300 ether, 0, 0, alice, block.timestamp);
        assertEq(a0, 100 ether);
        assertEq(a1, 200 ether);
        assertEq(t0.balanceOf(alice), 10_000 ether - 1_100 ether);
        assertEq(t1.balanceOf(alice), 10_000 ether - 2_200 ether);
    }

    function testToken0IsScaledDownWhenToken1IsLimiting() public {
        _seed();
        (uint256 q0, uint256 q1) = adder.optimalAmounts(address(pair), 100 ether, 150 ether, 0, 0);
        assertEq(q0, 75 ether);
        assertEq(q1, 150 ether);

        vm.prank(alice);
        (uint256 a0, uint256 a1,) =
            adder.addLiquidity(address(pair), 100 ether, 150 ether, 0, 0, alice, block.timestamp);
        assertEq(a0, 75 ether);
        assertEq(a1, 150 ether);
    }

    function testMinimumAmountsAreEnforced() public {
        _seed();
        vm.prank(alice);
        vm.expectRevert(LiquidityAdder.Insufficient1Amount.selector);
        adder.addLiquidity(address(pair), 100 ether, 300 ether, 0, 201 ether, alice, block.timestamp);

        vm.prank(alice);
        vm.expectRevert(LiquidityAdder.Insufficient0Amount.selector);
        adder.addLiquidity(address(pair), 100 ether, 150 ether, 76 ether, 0, alice, block.timestamp);
    }

    function testExpiredDeadlineReverts() public {
        uint256 deadline = block.timestamp + 60;
        vm.warp(deadline + 1);
        vm.prank(alice);
        vm.expectRevert(LiquidityAdder.Expired.selector);
        adder.addLiquidity(address(pair), 1 ether, 2 ether, 0, 0, alice, deadline);
    }
}
