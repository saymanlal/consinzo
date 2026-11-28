// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PoolFactory.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
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

contract PoolFactoryTest is Test {
    PoolFactory public factory;
    FeePool public pool;
    MockERC20 public t0;
    MockERC20 public t1;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        factory = new PoolFactory();
        MockERC20 a = new MockERC20();
        MockERC20 b = new MockERC20();
        (t0, t1) = address(a) < address(b) ? (a, b) : (b, a);
        // deliberately pass the tokens in reverse order
        pool = FeePool(factory.createPool(address(t1), address(t0), 3000));

        address[2] memory users = [alice, bob];
        for (uint256 i = 0; i < 2; i++) {
            t0.mint(users[i], 10_000 ether);
            t1.mint(users[i], 10_000 ether);
            vm.startPrank(users[i]);
            t0.approve(address(pool), type(uint256).max);
            t1.approve(address(pool), type(uint256).max);
            vm.stopPrank();
        }
    }

    function testFactoryDefaults() public view {
        assertEq(factory.owner(), address(this));
        assertEq(uint256(factory.protocolFeeBps()), 0);
        assertTrue(factory.feeTierEnabled(500));
        assertTrue(factory.feeTierEnabled(3000));
        assertTrue(factory.feeTierEnabled(10000));
        assertFalse(factory.feeTierEnabled(100));
    }

    function testCreatePoolSortsAndRegisters() public view {
        assertEq(pool.factory(), address(factory));
        assertEq(pool.token0(), address(t0));
        assertEq(pool.token1(), address(t1));
        assertEq(uint256(pool.fee()), 3000);
        assertEq(factory.getPool(address(t0), address(t1), 3000), address(pool));
        assertEq(factory.getPool(address(t1), address(t0), 3000), address(pool));
        assertEq(factory.getPool(address(t0), address(t1), 500), address(0));
        assertTrue(factory.isPool(address(pool)));
        assertEq(factory.allPoolsLength(), 1);
        assertEq(factory.allPools(0), address(pool));
    }

    function testDuplicatePoolReverts() public {
        vm.expectRevert(PoolFactory.PoolExists.selector);
        factory.createPool(address(t0), address(t1), 3000);
        vm.expectRevert(PoolFactory.PoolExists.selector);
        factory.createPool(address(t1), address(t0), 3000);
    }

    function testSecondTierIsSeparatePool() public {
        address other = factory.createPool(address(t0), address(t1), 500);
        assertTrue(other != address(pool));
        assertEq(uint256(FeePool(other).fee()), 500);
        assertEq(factory.allPoolsLength(), 2);
        assertEq(factory.getPool(address(t1), address(t0), 500), other);
    }

    function testAddLiquidityFirstDeposit() public {
        vm.prank(alice);
        uint256 liq = pool.addLiquidity(1000 ether, 4000 ether);
        assertEq(liq, 2000 ether);
        assertEq(pool.totalLiquidity(), 2000 ether);
        assertEq(pool.liquidityOf(alice), 2000 ether);
        assertEq(pool.reserve0(), 1000 ether);
        assertEq(pool.reserve1(), 4000 ether);
        assertEq(t0.balanceOf(address(pool)), 1000 ether);
    }

    function testSwapSplitsFee() public {
        factory.setProtocolFeeBps(2000);
        vm.prank(alice);
        pool.addLiquidity(1000 ether, 1000 ether);

        vm.prank(bob);
        uint256 out = pool.swap(address(t0), 10 ether, 0, bob);
        // fee = 0.03, protocol cut = 0.006, netIn = 9.97
        // out = 9.97e18 * 1000e18 / 1009.97e18
        assertEq(out, 9871580343970612988);
        assertEq(pool.totalFees0(), 0.03 ether);
        assertEq(pool.protocolFees0(), 0.006 ether);
        assertEq(pool.reserve0(), 1009.994 ether);
        assertEq(pool.reserve1(), 1000 ether - 9871580343970612988);
        assertEq(t0.balanceOf(address(pool)), 1010 ether);
        assertEq(t1.balanceOf(bob), 10_000 ether + 9871580343970612988);
        assertEq(pool.protocolFees1(), 0);
        assertEq(pool.totalFees1(), 0);
    }

    function testCollectProtocolFees() public {
        factory.setProtocolFeeBps(2000);
        vm.prank(alice);
        pool.addLiquidity(1000 ether, 1000 ether);
        vm.prank(bob);
        pool.swap(address(t0), 10 ether, 0, bob);

        (uint256 a0, uint256 a1) = factory.collectProtocolFees(address(pool), address(0xFEE));
        assertEq(a0, 0.006 ether);
        assertEq(a1, 0);
        assertEq(t0.balanceOf(address(0xFEE)), 0.006 ether);
        assertEq(pool.protocolFees0(), 0);
        assertEq(t0.balanceOf(address(pool)), pool.reserve0());
    }

    function testRemoveLiquidity() public {
        vm.prank(alice);
        pool.addLiquidity(1000 ether, 4000 ether);
        vm.prank(alice);
        (uint256 a0, uint256 a1) = pool.removeLiquidity(500 ether, alice);
        assertEq(a0, 250 ether);
        assertEq(a1, 1000 ether);
        assertEq(pool.totalLiquidity(), 1500 ether);
        assertEq(pool.reserve0(), 750 ether);
        assertEq(t1.balanceOf(alice), 7000 ether);
    }
}
