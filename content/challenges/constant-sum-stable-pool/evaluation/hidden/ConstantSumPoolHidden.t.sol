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

contract ConstantSumPoolHiddenTest is Test {
    MockERC20 public t0;
    MockERC20 public t1;
    ConstantSumPool public pool;
    address public lp = address(0xA11CE);
    address public trader = address(0xB0B);
    address public lp2 = address(0xCA201);

    function setUp() public {
        t0 = new MockERC20();
        t1 = new MockERC20();
        pool = new ConstantSumPool(address(t0), address(t1), 30);
        _fund(pool);
    }

    function _fund(ConstantSumPool p) internal {
        address[3] memory users = [lp, trader, lp2];
        for (uint256 i = 0; i < 3; i++) {
            t0.mint(users[i], 10_000 ether);
            t1.mint(users[i], 10_000 ether);
            vm.startPrank(users[i]);
            t0.approve(address(p), type(uint256).max);
            t1.approve(address(p), type(uint256).max);
            vm.stopPrank();
        }
    }

    function deploy(address a, address b, uint256 fee) external returns (ConstantSumPool) {
        return new ConstantSumPool(a, b, fee);
    }

    function _valuePerShare() internal view returns (uint256) {
        return ((pool.reserve0() + pool.reserve1()) * 1e18) / pool.totalSupply();
    }

    function testHiddenConstructorValidation() public {
        vm.expectRevert(ConstantSumPool.IdenticalTokens.selector);
        this.deploy(address(t0), address(t0), 30);
        vm.expectRevert(ConstantSumPool.FeeTooHigh.selector);
        this.deploy(address(t0), address(t1), 101);
        ConstantSumPool p = this.deploy(address(t0), address(t1), 100);
        assertEq(p.feeBps(), 100);
    }

    function testHiddenFeeRoundsUp() public view {
        assertEq(pool.getAmountOut(1), 0);
        assertEq(pool.getAmountOut(333), 332);
        assertEq(pool.getAmountOut(334), 332);
        assertEq(pool.getAmountOut(10_000), 9_970);
        assertEq(pool.getAmountOut(10_001), 9_970);
    }

    function testHiddenSwapCheckOrder() public {
        vm.prank(lp);
        pool.addLiquidity(100 ether, 100 ether);
        vm.startPrank(trader);
        vm.expectRevert(ConstantSumPool.InvalidToken.selector);
        pool.swap(address(0xDEAD), 0, 0);
        vm.expectRevert(ConstantSumPool.ZeroAmount.selector);
        pool.swap(address(t0), 0, 0);
        // too much for the reserve and below the minimum: slippage is reported first
        vm.expectRevert(ConstantSumPool.SlippageExceeded.selector);
        pool.swap(address(t0), 500 ether, 500 ether);
        vm.expectRevert(ConstantSumPool.InsufficientLiquidity.selector);
        pool.swap(address(t0), 500 ether, 0);
        vm.expectRevert(ConstantSumPool.SlippageExceeded.selector);
        pool.swap(address(t1), 10 ether, 9.97 ether + 1);
        assertEq(pool.swap(address(t1), 10 ether, 9.97 ether), 9.97 ether);
        vm.stopPrank();
        assertEq(pool.reserve0(), 90.03 ether);
        assertEq(pool.reserve1(), 110 ether);
    }

    function testHiddenDrainedSideLiquidity() public {
        ConstantSumPool free = new ConstantSumPool(address(t0), address(t1), 0);
        _fund(free);
        vm.prank(lp);
        free.addLiquidity(1_000 ether, 1_000 ether);
        // without a fee the whole token1 reserve can be taken
        vm.prank(trader);
        assertEq(free.swap(address(t0), 1_000 ether, 0), 1_000 ether);
        assertEq(free.reserve0(), 2_000 ether);
        assertEq(free.reserve1(), 0);
        vm.prank(trader);
        vm.expectRevert(ConstantSumPool.InsufficientLiquidity.selector);
        free.swap(address(t0), 1, 0);

        // only token0 can be added while reserve1 is zero
        vm.prank(lp2);
        vm.expectRevert(ConstantSumPool.ZeroShares.selector);
        free.addLiquidity(0, 500 ether);
        vm.prank(lp2);
        (uint256 shares, uint256 a0, uint256 a1) = free.addLiquidity(500 ether, 700 ether);
        assertEq(shares, 500 ether);
        assertEq(a0, 500 ether);
        assertEq(a1, 0);
        assertEq(t1.balanceOf(lp2), 20_000 ether); // funded twice, nothing pulled

        vm.prank(lp2);
        (uint256 o0, uint256 o1) = free.removeLiquidity(500 ether, 0, 0);
        assertEq(o0, 500 ether);
        assertEq(o1, 0);
    }

    function testHiddenAddRoundsInPoolsFavour() public {
        vm.prank(lp);
        pool.addLiquidity(1_000 ether, 999 ether); // supply 1999e18
        vm.prank(trader);
        pool.swap(address(t0), 7 ether + 3, 0);
        uint256 before = _valuePerShare();
        uint256 r0 = pool.reserve0();
        uint256 r1 = pool.reserve1();
        uint256 supply = pool.totalSupply();

        vm.prank(lp2);
        (uint256 shares, uint256 a0, uint256 a1) = pool.addLiquidity(10 ether + 1, 55 ether);
        assertEq(shares, ((10 ether + 1) * supply) / r0);
        assertLe(a0, 10 ether + 1);
        assertLe(a1, 55 ether);
        // amounts are the ceiling of the proportional amounts
        assertGe(a0 * supply, shares * r0);
        assertLt((a0 - 1) * supply, shares * r0);
        assertGe(a1 * supply, shares * r1);
        assertLt((a1 - 1) * supply, shares * r1);
        assertGe(_valuePerShare(), before);

        // an immediate exit never returns more than was put in
        vm.prank(lp2);
        (uint256 o0, uint256 o1) = pool.removeLiquidity(shares, 0, 0);
        assertLe(o0, a0);
        assertLe(o1, a1);
        assertGe(_valuePerShare(), before);
    }

    function testHiddenRemoveValidationAndSlippage() public {
        vm.prank(lp);
        pool.addLiquidity(600 ether, 400 ether);
        vm.startPrank(lp);
        vm.expectRevert(ConstantSumPool.ZeroAmount.selector);
        pool.removeLiquidity(0, 0, 0);
        vm.expectRevert(ConstantSumPool.InsufficientShares.selector);
        pool.removeLiquidity(1_000 ether + 1, 0, 0);
        vm.expectRevert(ConstantSumPool.SlippageExceeded.selector);
        pool.removeLiquidity(100 ether, 60 ether + 1, 0);
        vm.expectRevert(ConstantSumPool.SlippageExceeded.selector);
        pool.removeLiquidity(100 ether, 0, 40 ether + 1);
        (uint256 o0, uint256 o1) = pool.removeLiquidity(100 ether, 60 ether, 40 ether);
        vm.stopPrank();
        assertEq(o0, 60 ether);
        assertEq(o1, 40 ether);
        vm.prank(trader);
        vm.expectRevert(ConstantSumPool.InsufficientShares.selector);
        pool.removeLiquidity(1, 0, 0);
        vm.prank(trader);
        vm.expectRevert(ConstantSumPool.ZeroShares.selector);
        pool.addLiquidity(0, 5 ether);
    }

    function testHiddenDonationsAreIgnored() public {
        vm.prank(lp);
        pool.addLiquidity(100 ether, 100 ether);
        vm.prank(trader);
        t1.transfer(address(pool), 5_000 ether);
        assertEq(pool.reserve1(), 100 ether);
        vm.prank(trader);
        vm.expectRevert(ConstantSumPool.InsufficientLiquidity.selector);
        pool.swap(address(t0), 200 ether, 0);
        vm.prank(lp2);
        (uint256 shares, uint256 a0, uint256 a1) = pool.addLiquidity(50 ether, 50 ether);
        assertEq(shares, 100 ether);
        assertEq(a0, 50 ether);
        assertEq(a1, 50 ether);
    }

    function testHiddenShareValueNeverDecreases() public {
        vm.prank(lp);
        pool.addLiquidity(1_000 ether + 7, 1_000 ether + 13);
        uint256 last = _valuePerShare();
        uint256[6] memory ins = [uint256(3), 17 ether + 5, 333, 250 ether + 1, 1 ether, 99];
        for (uint256 i = 0; i < 6; i++) {
            vm.prank(trader);
            pool.swap(i % 2 == 0 ? address(t0) : address(t1), ins[i], 0);
            uint256 v = _valuePerShare();
            assertGe(v, last);
            last = v;
            vm.prank(lp2);
            (uint256 shares, , ) = pool.addLiquidity(ins[i] + 1 ether, ins[i] + 2 ether);
            v = _valuePerShare();
            assertGe(v, last);
            last = v;
            vm.prank(lp2);
            pool.removeLiquidity(shares / 2 + 1, 0, 0);
            v = _valuePerShare();
            assertGe(v, last);
            last = v;
        }
        assertGe(t0.balanceOf(address(pool)), pool.reserve0());
        assertGe(t1.balanceOf(address(pool)), pool.reserve1());
        // the first provider leaves with more than the 2000 + 20 wei it put in
        uint256 lpShares = pool.balanceOf(lp);
        vm.prank(lp);
        (uint256 o0, uint256 o1) = pool.removeLiquidity(lpShares, 0, 0);
        assertGt(o0 + o1, 2_000 ether + 20);
    }
}
