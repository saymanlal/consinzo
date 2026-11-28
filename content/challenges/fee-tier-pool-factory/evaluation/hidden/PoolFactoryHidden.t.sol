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

contract PoolFactoryHiddenTest is Test {
    PoolFactory public factory;
    MockERC20 public t0;
    MockERC20 public t1;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public mallory = address(0xBAD);

    function setUp() public {
        factory = new PoolFactory();
        MockERC20 a = new MockERC20();
        MockERC20 b = new MockERC20();
        (t0, t1) = address(a) < address(b) ? (a, b) : (b, a);
        t0.mint(alice, 100_000 ether);
        t1.mint(alice, 100_000 ether);
        t0.mint(bob, 100_000 ether);
        t1.mint(bob, 100_000 ether);
    }

    function _pool(uint24 fee) internal returns (FeePool p) {
        p = FeePool(factory.createPool(address(t0), address(t1), fee));
        address[2] memory users = [alice, bob];
        for (uint256 i = 0; i < 2; i++) {
            vm.startPrank(users[i]);
            t0.approve(address(p), type(uint256).max);
            t1.approve(address(p), type(uint256).max);
            vm.stopPrank();
        }
    }

    function testHiddenFeeTierValidation() public {
        vm.expectRevert(PoolFactory.InvalidFee.selector);
        factory.enableFeeTier(0);
        vm.expectRevert(PoolFactory.InvalidFee.selector);
        factory.enableFeeTier(100_000);
        vm.expectRevert(PoolFactory.TierAlreadyEnabled.selector);
        factory.enableFeeTier(3000);
        vm.prank(mallory);
        vm.expectRevert(PoolFactory.NotOwner.selector);
        factory.enableFeeTier(100);
        assertFalse(factory.feeTierEnabled(100));

        vm.expectRevert(PoolFactory.TierNotEnabled.selector);
        factory.createPool(address(t0), address(t1), 100);
        factory.enableFeeTier(100);
        factory.enableFeeTier(99_999);
        assertTrue(factory.feeTierEnabled(100));
        address p = factory.createPool(address(t0), address(t1), 100);
        assertEq(uint256(FeePool(p).fee()), 100);
    }

    function testHiddenCreatePoolChecksAndOrder() public {
        vm.expectRevert(PoolFactory.IdenticalTokens.selector);
        factory.createPool(address(t0), address(t0), 3000);
        // identical beats zero address and unknown tier
        vm.expectRevert(PoolFactory.IdenticalTokens.selector);
        factory.createPool(address(0), address(0), 7);
        vm.expectRevert(PoolFactory.ZeroAddress.selector);
        factory.createPool(address(0), address(t1), 3000);
        vm.expectRevert(PoolFactory.ZeroAddress.selector);
        factory.createPool(address(t0), address(0), 7);
        vm.expectRevert(PoolFactory.TierNotEnabled.selector);
        factory.createPool(address(t0), address(t1), 7);

        // anyone may create
        vm.prank(mallory);
        address p = factory.createPool(address(t1), address(t0), 10000);
        assertEq(FeePool(p).token0(), address(t0));
        assertEq(FeePool(p).token1(), address(t1));
        assertEq(FeePool(p).factory(), address(factory));
        vm.expectRevert(PoolFactory.PoolExists.selector);
        factory.createPool(address(t0), address(t1), 10000);
        vm.expectRevert(PoolFactory.PoolExists.selector);
        factory.createPool(address(t1), address(t0), 10000);
        assertEq(factory.allPoolsLength(), 1);
    }

    function testHiddenTiersKeepSeparateBooks() public {
        FeePool p500 = _pool(500);
        FeePool p3000 = _pool(3000);
        assertEq(factory.allPools(0), address(p500));
        assertEq(factory.allPools(1), address(p3000));
        vm.startPrank(alice);
        p500.addLiquidity(1000 ether, 1000 ether);
        p3000.addLiquidity(1000 ether, 1000 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        uint256 out500 = p500.swap(address(t0), 10 ether, 0, bob);
        uint256 out3000 = p3000.swap(address(t0), 10 ether, 0, bob);
        vm.stopPrank();

        assertEq(out500, 9896088594497992564);
        assertEq(out3000, 9871580343970612988);
        assertEq(p500.totalFees0(), 0.005 ether);
        assertEq(p3000.totalFees0(), 0.03 ether);
        // no protocol fee configured: the whole input joins the reserve
        assertEq(p500.reserve0(), 1010 ether);
        assertEq(p3000.reserve0(), 1010 ether);
        assertEq(p500.reserve1(), 990103911405502007436);
        assertEq(p3000.reserve1(), 990128419656029387012);
        assertEq(p500.protocolFees0(), 0);
        assertEq(p3000.protocolFees0(), 0);
    }

    function testHiddenProtocolFeeChangeAndBothDirections() public {
        FeePool p = _pool(3000);
        vm.prank(alice);
        assertEq(p.addLiquidity(1000 ether, 4000 ether), 2000 ether);

        vm.expectRevert(PoolFactory.InvalidProtocolFee.selector);
        factory.setProtocolFeeBps(2501);
        vm.prank(mallory);
        vm.expectRevert(PoolFactory.NotOwner.selector);
        factory.setProtocolFeeBps(100);

        factory.setProtocolFeeBps(2500);
        vm.prank(bob);
        uint256 out1 = p.swap(address(t0), 10 ether, 0, bob);
        assertEq(out1, 39486321375882451954);
        assertEq(p.reserve0(), 1009992500000000000000);
        assertEq(p.reserve1(), 3960513678624117548046);
        assertEq(p.protocolFees0(), 0.0075 ether);

        factory.setProtocolFeeBps(1000);
        vm.prank(bob);
        uint256 out2 = p.swap(address(t1), 20 ether, 0, alice);
        assertEq(out2, 5059536443836052228);
        assertEq(p.reserve0(), 1004932963556163947772);
        assertEq(p.reserve1(), 3980507678624117548046);
        assertEq(p.protocolFees0(), 0.0075 ether);
        assertEq(p.protocolFees1(), 0.006 ether);
        assertEq(p.totalFees0(), 0.03 ether);
        assertEq(p.totalFees1(), 0.06 ether);
        // output of the second swap went to the chosen recipient
        assertEq(t0.balanceOf(alice), 100_000 ether - 1000 ether + 5059536443836052228);
        // balance == reserve + protocol fees for both tokens
        assertEq(t0.balanceOf(address(p)), p.reserve0() + p.protocolFees0());
        assertEq(t1.balanceOf(address(p)), p.reserve1() + p.protocolFees1());

        // a later provider is priced by the smaller of the two ratios
        vm.prank(bob);
        uint256 liq = p.addLiquidity(100 ether, 100 ether);
        assertEq(liq, 50244847177164849367);
        assertEq(p.reserve0(), 1104932963556163947772);
        assertEq(p.reserve1(), 4080507678624117548046);
    }

    function testHiddenProtocolFeesDoNotLeakToProviders() public {
        FeePool p = _pool(3000);
        factory.setProtocolFeeBps(2500);
        vm.prank(alice);
        p.addLiquidity(1000 ether, 4000 ether);
        vm.prank(bob);
        p.swap(address(t0), 10 ether, 0, bob);
        vm.prank(bob);
        p.swap(address(t1), 20 ether, 0, bob);
        uint256 pf0 = p.protocolFees0();
        uint256 pf1 = p.protocolFees1();
        assertEq(pf0, 0.0075 ether);
        assertEq(pf1, 0.015 ether);

        uint256 r0 = p.reserve0();
        uint256 r1 = p.reserve1();
        vm.prank(alice);
        (uint256 a0, uint256 a1) = p.removeLiquidity(2000 ether, address(0xCAFE));
        assertEq(a0, r0);
        assertEq(a1, r1);
        assertEq(p.totalLiquidity(), 0);
        assertEq(p.reserve0(), 0);
        assertEq(p.reserve1(), 0);
        assertEq(t0.balanceOf(address(0xCAFE)), r0);
        // exactly the protocol fees are left behind
        assertEq(t0.balanceOf(address(p)), pf0);
        assertEq(t1.balanceOf(address(p)), pf1);

        (uint256 c0, uint256 c1) = factory.collectProtocolFees(address(p), address(0xFEE));
        assertEq(c0, pf0);
        assertEq(c1, pf1);
        assertEq(t0.balanceOf(address(p)), 0);
        assertEq(t1.balanceOf(address(p)), 0);
        assertEq(t1.balanceOf(address(0xFEE)), pf1);
        // a second collection moves nothing
        (c0, c1) = factory.collectProtocolFees(address(p), address(0xFEE));
        assertEq(c0, 0);
        assertEq(c1, 0);
    }

    function testHiddenCollectAccessControl() public {
        FeePool p = _pool(3000);
        vm.expectRevert(FeePool.NotFactory.selector);
        p.collectProtocolFees(address(this));
        vm.prank(mallory);
        vm.expectRevert(FeePool.NotFactory.selector);
        p.collectProtocolFees(mallory);
        vm.prank(mallory);
        vm.expectRevert(PoolFactory.NotOwner.selector);
        factory.collectProtocolFees(address(p), mallory);
        vm.expectRevert(PoolFactory.UnknownPool.selector);
        factory.collectProtocolFees(address(0x1234), address(this));
        // a pool deployed outside the factory is not registered
        FeePool rogue = new FeePool(address(t0), address(t1), 3000);
        assertFalse(factory.isPool(address(rogue)));
        vm.expectRevert(PoolFactory.UnknownPool.selector);
        factory.collectProtocolFees(address(rogue), address(this));
    }

    function testHiddenSwapValidationAndRounding() public {
        FeePool p = _pool(3000);
        factory.setProtocolFeeBps(2500);
        vm.prank(alice);
        assertEq(p.addLiquidity(1000, 1000), 1000);

        vm.prank(bob);
        vm.expectRevert(FeePool.InvalidToken.selector);
        p.swap(address(0xDEAD), 100, 0, bob);
        vm.prank(bob);
        vm.expectRevert(FeePool.ZeroAmount.selector);
        p.swap(address(t0), 0, 0, bob);
        // fee = 3, protocol cut = floor(3 * 2500 / 10000) = 0, netIn = 997, out = 997000 / 1997 = 499
        vm.prank(bob);
        vm.expectRevert(FeePool.InsufficientOutput.selector);
        p.swap(address(t1), 1000, 500, bob);
        vm.prank(bob);
        assertEq(p.swap(address(t1), 1000, 499, bob), 499);
        assertEq(p.reserve1(), 2000);
        assertEq(p.reserve0(), 501);
        assertEq(p.totalFees1(), 3);
        assertEq(p.protocolFees1(), 0);
        // 1 wei in: 1 * 501 / 2001 = 0 out is rejected even with minAmountOut = 0
        vm.prank(bob);
        vm.expectRevert(FeePool.InsufficientOutput.selector);
        p.swap(address(t1), 1, 0, bob);
    }

    function testHiddenLiquidityValidation() public {
        FeePool p = _pool(500);
        vm.prank(alice);
        vm.expectRevert(FeePool.ZeroLiquidity.selector);
        p.addLiquidity(0, 1000 ether);
        vm.prank(alice);
        p.addLiquidity(4 ether, 9 ether);
        assertEq(p.totalLiquidity(), 6 ether);
        // one-sided top-up earns nothing and is rejected
        vm.prank(bob);
        vm.expectRevert(FeePool.ZeroLiquidity.selector);
        p.addLiquidity(1 ether, 0);
        vm.prank(bob);
        vm.expectRevert(FeePool.InsufficientLiquidity.selector);
        p.removeLiquidity(1, bob);
        vm.prank(alice);
        vm.expectRevert(FeePool.ZeroAmount.selector);
        p.removeLiquidity(0, alice);
        vm.prank(alice);
        vm.expectRevert(FeePool.InsufficientLiquidity.selector);
        p.removeLiquidity(6 ether + 1, alice);
        vm.prank(alice);
        (uint256 a0, uint256 a1) = p.removeLiquidity(2 ether, alice);
        assertEq(a0, 1333333333333333333);
        assertEq(a1, 3 ether);
        assertEq(p.liquidityOf(alice), 4 ether);
    }
}
