// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SwapRouter.sol";

contract MockToken {
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
        uint256 a = allowance[from][msg.sender];
        if (a != type(uint256).max) allowance[from][msg.sender] = a - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

/// Fixed-rate exchange: takes tokenIn from the caller, sends tokenOut to `recipient`.
contract MockExchange {
    uint256 public rate = 2e18; // tokenOut per tokenIn, 1e18 scaled

    function setRate(uint256 r) external {
        rate = r;
    }

    function trade(address tokenIn, address tokenOut, uint256 amountIn, address recipient) external {
        MockToken(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        MockToken(tokenOut).transfer(recipient, (amountIn * rate) / 1e18);
    }
}

/// Runs the drain from a contract and ignores reverts, so only balances tell the story.
contract Drainer {
    function run(SwapRouter router, MockToken junk, MockToken prize, address victim, uint256 amount) external {
        junk.approve(address(router), type(uint256).max);
        bytes memory data = abi.encodeWithSelector(MockToken.transferFrom.selector, victim, address(this), amount);
        try router.swap(address(junk), address(junk), 1, 0, address(prize), data) {} catch {}
    }
}

contract SwapRouterHiddenTest is Test {
    SwapRouter public router;
    MockToken public usd;
    MockToken public gem;
    MockExchange public exchange;

    address public victim = address(0xA11CE);
    address public victim2 = address(0xCAFE);
    address public trader = address(0xB0B);
    address public attacker = address(0xBAD);

    function setUp() public {
        router = new SwapRouter();
        usd = new MockToken();
        gem = new MockToken();
        exchange = new MockExchange();
        gem.mint(address(exchange), 1_000_000e18);
        router.setAllowedTarget(address(exchange), true);

        usd.mint(victim, 1_000e18);
        vm.prank(victim);
        usd.approve(address(router), type(uint256).max);
        gem.mint(victim2, 50e18);
        vm.prank(victim2);
        gem.approve(address(router), 50e18);

        usd.mint(trader, 100e18);
        vm.prank(trader);
        usd.approve(address(router), type(uint256).max);
    }

    function testHiddenDrainWithWorthlessInputToken() public {
        // The attacker pays with a token they minted themselves and targets the real one.
        MockToken junk = new MockToken();
        Drainer drainer = new Drainer();
        junk.mint(address(drainer), 10);
        drainer.run(router, junk, usd, victim, 1_000e18);
        drainer.run(router, junk, gem, victim2, 50e18);
        assertEq(usd.balanceOf(victim), 1_000e18);
        assertEq(gem.balanceOf(victim2), 50e18);
        assertEq(usd.balanceOf(address(drainer)), 0);
        assertEq(gem.balanceOf(address(drainer)), 0);
    }

    function testHiddenAllowlistCheckedBeforeTokensMove() public {
        MockToken junk = new MockToken();
        junk.mint(attacker, 5);
        vm.prank(attacker);
        junk.approve(address(router), 5);
        bytes memory data = abi.encodeWithSelector(MockToken.transferFrom.selector, victim, attacker, 1e18);
        vm.expectRevert(SwapRouter.TargetNotAllowed.selector);
        vm.prank(attacker);
        router.swap(address(junk), address(usd), 5, 0, address(usd), data);
        assertEq(junk.balanceOf(attacker), 5);
        assertEq(usd.balanceOf(attacker), 0);
    }

    function testHiddenRevokedExchangeStopsWorking() public {
        router.setAllowedTarget(address(exchange), false);
        bytes memory data = abi.encodeWithSelector(MockExchange.trade.selector, address(usd), address(gem), 10e18, address(router));
        vm.expectRevert(SwapRouter.TargetNotAllowed.selector);
        vm.prank(trader);
        router.swap(address(usd), address(gem), 10e18, 0, address(exchange), data);
        assertEq(usd.balanceOf(trader), 100e18);
    }

    function testHiddenOnlyOwnerManagesAllowlist() public {
        vm.expectRevert(SwapRouter.NotOwner.selector);
        vm.prank(attacker);
        router.setAllowedTarget(address(usd), true);
        assertFalse(router.allowedTarget(address(usd)));
    }

    function testHiddenTwoSwapsKeepOtherApprovalsIntact() public {
        exchange.setRate(0.5e18);
        bytes memory data = abi.encodeWithSelector(MockExchange.trade.selector, address(usd), address(gem), 40e18, address(router));
        vm.prank(trader);
        uint256 out1 = router.swap(address(usd), address(gem), 40e18, 20e18, address(exchange), data);
        vm.prank(trader);
        uint256 out2 = router.swap(address(usd), address(gem), 40e18, 20e18, address(exchange), data);
        assertEq(out1 + out2, 40e18);
        assertEq(gem.balanceOf(trader), 40e18);
        assertEq(usd.balanceOf(trader), 20e18);
        assertEq(usd.balanceOf(victim), 1_000e18);
        assertEq(usd.balanceOf(address(router)), 0);
        assertEq(gem.balanceOf(address(router)), 0);
        assertEq(usd.allowance(address(router), address(exchange)), 0);
    }

    function testHiddenZeroAmountAndFailedExchangeCall() public {
        bytes memory data = abi.encodeWithSelector(MockExchange.trade.selector, address(usd), address(gem), 1e18, address(router));
        vm.expectRevert(SwapRouter.ZeroAmount.selector);
        vm.prank(trader);
        router.swap(address(usd), address(gem), 0, 0, address(exchange), data);
    }

    function testHiddenExchangeRevertBubblesAsSwapCallFailed() public {
        // The exchange tries to pull more than the router approved.
        bytes memory data = abi.encodeWithSelector(MockExchange.trade.selector, address(usd), address(gem), 11e18, address(router));
        vm.expectRevert(SwapRouter.SwapCallFailed.selector);
        vm.prank(trader);
        router.swap(address(usd), address(gem), 10e18, 0, address(exchange), data);
        assertEq(usd.balanceOf(trader), 100e18);
    }
}
