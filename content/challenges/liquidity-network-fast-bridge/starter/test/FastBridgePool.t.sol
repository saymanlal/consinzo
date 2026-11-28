// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FastBridgePool.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

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

contract FastBridgePoolTest is Test {
    FastBridgePool public pool;
    MockERC20 public usd;
    address public relayer = address(0x4E1A);
    address public settler = address(0x5E77);
    address public lp1 = address(0x1111);
    address public lp2 = address(0x2222);
    address public user = address(0xA11CE);

    bytes32 internal constant ID1 = keccak256("transfer-1");

    function setUp() public {
        usd = new MockERC20();
        pool = new FastBridgePool(address(usd), relayer, settler, 10, 2_000); // 0.10% fee, 20% to protocol
        usd.mint(lp1, 1_000_000e18);
        usd.mint(lp2, 1_000_000e18);
        usd.mint(settler, 1_000_000e18);
        vm.prank(lp1);
        usd.approve(address(pool), type(uint256).max);
        vm.prank(lp2);
        usd.approve(address(pool), type(uint256).max);
        vm.prank(settler);
        usd.approve(address(pool), type(uint256).max);
    }

    function testFirstDepositMintsOneToOne() public {
        vm.prank(lp1);
        uint256 shares = pool.deposit(100_000e18);
        assertEq(shares, 100_000e18);
        assertEq(pool.sharesOf(lp1), 100_000e18);
        assertEq(pool.totalShares(), 100_000e18);
        assertEq(pool.idle(), 100_000e18);
        assertEq(pool.totalAssets(), 100_000e18);
    }

    function testFulfillPaysUserMinusFee() public {
        vm.prank(lp1);
        pool.deposit(100_000e18);
        assertEq(pool.quoteFee(10_000e18), 10e18);

        vm.prank(relayer);
        uint256 paid = pool.fulfill(ID1, user, 10_000e18);
        assertEq(paid, 9_990e18);
        assertEq(usd.balanceOf(user), 9_990e18);
        assertEq(pool.idle(), 90_010e18);
        assertEq(pool.outstanding(), 9_990e18);
        assertEq(pool.totalAssets(), 100_000e18); // fee not earned yet
        assertTrue(pool.transferState(ID1) == FastBridgePool.State.Fulfilled);
    }

    function testSettleRepaysPoolAndRealisesFee() public {
        vm.prank(lp1);
        pool.deposit(100_000e18);
        vm.prank(relayer);
        pool.fulfill(ID1, user, 10_000e18);
        vm.prank(settler);
        pool.settle(ID1, user, 10_000e18);

        assertEq(pool.outstanding(), 0);
        assertEq(pool.protocolFees(), 2e18);
        assertEq(pool.idle(), 100_008e18);
        assertEq(pool.totalAssets(), 100_008e18);
        assertEq(usd.balanceOf(address(pool)), 100_010e18);
        assertTrue(pool.transferState(ID1) == FastBridgePool.State.Settled);
    }

    function testLaterDepositorPaysHigherSharePrice() public {
        vm.prank(lp1);
        pool.deposit(100_000e18);
        vm.prank(relayer);
        pool.fulfill(ID1, user, 10_000e18);
        vm.prank(settler);
        pool.settle(ID1, user, 10_000e18);

        vm.prank(lp2);
        uint256 shares = pool.deposit(50_004e18);
        assertEq(shares, 50_000e18);

        vm.prank(lp1);
        uint256 out = pool.withdraw(100_000e18);
        assertEq(out, 100_008e18); // lp1 earned the whole LP share of the fee
    }

    function testSlowPathForwardsFullAmount() public {
        vm.prank(settler);
        pool.settle(ID1, user, 10_000e18);
        assertEq(usd.balanceOf(user), 10_000e18);
        assertEq(usd.balanceOf(address(pool)), 0);
        assertEq(pool.totalAssets(), 0);
        assertTrue(pool.transferState(ID1) == FastBridgePool.State.Settled);
    }

    function testOnlyRelayerFulfills() public {
        vm.prank(lp1);
        pool.deposit(100_000e18);
        vm.prank(user);
        vm.expectRevert(FastBridgePool.NotRelayer.selector);
        pool.fulfill(ID1, user, 10_000e18);
    }
}
