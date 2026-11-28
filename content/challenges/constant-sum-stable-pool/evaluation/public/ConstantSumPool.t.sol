// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ConstantSumPool.sol";

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

contract ConstantSumPoolTest is Test {
    MockERC20 public t0;
    MockERC20 public t1;
    ConstantSumPool public pool;
    address public lp = address(0xA11CE);
    address public trader = address(0xB0B);

    function setUp() public {
        t0 = new MockERC20();
        t1 = new MockERC20();
        pool = new ConstantSumPool(address(t0), address(t1), 30); // 0.30%
        address[2] memory users = [lp, trader];
        for (uint256 i = 0; i < 2; i++) {
            t0.mint(users[i], 10_000 ether);
            t1.mint(users[i], 10_000 ether);
            vm.startPrank(users[i]);
            t0.approve(address(pool), type(uint256).max);
            t1.approve(address(pool), type(uint256).max);
            vm.stopPrank();
        }
    }

    function testInitialLiquidity() public {
        vm.prank(lp);
        (uint256 shares, uint256 a0, uint256 a1) = pool.addLiquidity(1_000 ether, 1_000 ether);
        assertEq(shares, 2_000 ether);
        assertEq(a0, 1_000 ether);
        assertEq(a1, 1_000 ether);
        assertEq(pool.reserve0(), 1_000 ether);
        assertEq(pool.reserve1(), 1_000 ether);
        assertEq(pool.totalSupply(), 2_000 ether);
        assertEq(pool.balanceOf(lp), 2_000 ether);
    }

    function testSwapOneToOneMinusFee() public {
        vm.prank(lp);
        pool.addLiquidity(1_000 ether, 1_000 ether);
        assertEq(pool.getAmountOut(100 ether), 99.7 ether);
        vm.prank(trader);
        uint256 out = pool.swap(address(t0), 100 ether, 99.7 ether);
        assertEq(out, 99.7 ether);
        assertEq(t1.balanceOf(trader), 10_099.7 ether);
        assertEq(t0.balanceOf(trader), 9_900 ether);
        assertEq(pool.reserve0(), 1_100 ether);
        assertEq(pool.reserve1(), 900.3 ether);
    }

    function testProportionalAdd() public {
        vm.prank(lp);
        pool.addLiquidity(1_000 ether, 1_000 ether);
        vm.prank(trader);
        pool.swap(address(t0), 100 ether, 0);
        // reserves 1100 / 900.3, supply 2000. token0 is the limiting side.
        vm.prank(trader);
        (uint256 shares, uint256 a0, uint256 a1) = pool.addLiquidity(110 ether, 200 ether);
        assertEq(shares, 200 ether);
        assertEq(a0, 110 ether);
        assertEq(a1, 90.03 ether);
        assertEq(pool.reserve0(), 1_210 ether);
        assertEq(pool.reserve1(), 990.33 ether);
    }

    function testRemoveLiquidityIncludesFees() public {
        vm.prank(lp);
        pool.addLiquidity(1_000 ether, 1_000 ether);
        vm.prank(trader);
        pool.swap(address(t0), 100 ether, 0);
        vm.prank(lp);
        (uint256 a0, uint256 a1) = pool.removeLiquidity(2_000 ether, 0, 0);
        assertEq(a0, 1_100 ether);
        assertEq(a1, 900.3 ether);
        assertEq(a0 + a1, 2_000.3 ether); // the 0.3 fee belongs to the provider
        assertEq(pool.totalSupply(), 0);
        assertEq(pool.reserve0(), 0);
        assertEq(pool.reserve1(), 0);
    }

    function testSwapLimitedByReserve() public {
        vm.prank(lp);
        pool.addLiquidity(1_000 ether, 1_000 ether);
        vm.prank(trader);
        vm.expectRevert(ConstantSumPool.InsufficientLiquidity.selector);
        pool.swap(address(t1), 1_100 ether, 0);
    }
}
