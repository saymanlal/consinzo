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

contract SwapRouterTest is Test {
    SwapRouter public router;
    MockToken public usd;
    MockToken public gem;
    MockExchange public exchange;

    address public victim = address(0xA11CE);
    address public trader = address(0xB0B);
    address public attacker = address(0xBAD);

    function setUp() public {
        router = new SwapRouter();
        usd = new MockToken();
        gem = new MockToken();
        exchange = new MockExchange();
        gem.mint(address(exchange), 1_000_000e18);
        router.setAllowedTarget(address(exchange), true);

        // The victim is an ordinary user with a standing unlimited approval.
        usd.mint(victim, 1_000e18);
        vm.prank(victim);
        usd.approve(address(router), type(uint256).max);

        usd.mint(trader, 100e18);
        vm.prank(trader);
        usd.approve(address(router), type(uint256).max);

        usd.mint(attacker, 1);
        vm.prank(attacker);
        usd.approve(address(router), type(uint256).max);
    }

    function _tradeData(uint256 amountIn) internal view returns (bytes memory) {
        return abi.encodeWithSelector(MockExchange.trade.selector, address(usd), address(gem), amountIn, address(router));
    }

    function testSwapThroughAllowedExchange() public {
        bytes memory data = _tradeData(100e18);
        vm.prank(trader);
        uint256 out = router.swap(address(usd), address(gem), 100e18, 200e18, address(exchange), data);
        assertEq(out, 200e18);
        assertEq(gem.balanceOf(trader), 200e18);
        assertEq(usd.balanceOf(trader), 0);
        assertEq(usd.allowance(address(router), address(exchange)), 0);
    }

    function testCannotDrainApprovalsThroughTokenCall() public {
        // target = the token itself, data = transferFrom(victim, attacker, everything)
        bytes memory data = abi.encodeWithSelector(MockToken.transferFrom.selector, victim, attacker, 1_000e18);
        vm.expectRevert(SwapRouter.TargetNotAllowed.selector);
        vm.prank(attacker);
        router.swap(address(usd), address(usd), 1, 0, address(usd), data);
        assertEq(usd.balanceOf(victim), 1_000e18);
        assertEq(usd.balanceOf(attacker), 1);
    }

    function testUnlistedExchangeRejected() public {
        MockExchange rogue = new MockExchange();
        gem.mint(address(rogue), 1_000e18);
        bytes memory data = _tradeData(10e18);
        vm.expectRevert(SwapRouter.TargetNotAllowed.selector);
        vm.prank(trader);
        router.swap(address(usd), address(gem), 10e18, 0, address(rogue), data);
        assertEq(usd.balanceOf(trader), 100e18);
    }

    function testMinimumOutputEnforced() public {
        bytes memory data = _tradeData(100e18);
        vm.expectRevert(SwapRouter.InsufficientOutput.selector);
        vm.prank(trader);
        router.swap(address(usd), address(gem), 100e18, 200e18 + 1, address(exchange), data);
        assertEq(usd.balanceOf(trader), 100e18);
    }
}
