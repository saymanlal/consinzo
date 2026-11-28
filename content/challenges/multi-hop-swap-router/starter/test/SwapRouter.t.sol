// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SwapRouter.sol";

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

contract MockPair {
    address public token0;
    address public token1;
    uint256 private reserve0;
    uint256 private reserve1;

    constructor(address a, address b) {
        (token0, token1) = a < b ? (a, b) : (b, a);
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }

    function sync() external {
        reserve0 = MockERC20(token0).balanceOf(address(this));
        reserve1 = MockERC20(token1).balanceOf(address(this));
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to) external {
        require(amount0Out > 0 || amount1Out > 0, "NO_OUTPUT");
        require(amount0Out < reserve0 && amount1Out < reserve1, "LIQUIDITY");
        if (amount0Out > 0) MockERC20(token0).transfer(to, amount0Out);
        if (amount1Out > 0) MockERC20(token1).transfer(to, amount1Out);
        uint256 b0 = MockERC20(token0).balanceOf(address(this));
        uint256 b1 = MockERC20(token1).balanceOf(address(this));
        uint256 in0 = b0 > reserve0 - amount0Out ? b0 - (reserve0 - amount0Out) : 0;
        uint256 in1 = b1 > reserve1 - amount1Out ? b1 - (reserve1 - amount1Out) : 0;
        require(in0 > 0 || in1 > 0, "NO_INPUT");
        require((b0 * 1000 - in0 * 3) * (b1 * 1000 - in1 * 3) >= reserve0 * reserve1 * 1_000_000, "K");
        reserve0 = b0;
        reserve1 = b1;
    }
}

contract MockFactory {
    mapping(address => mapping(address => address)) public getPair;

    function createPair(address a, address b) external returns (MockPair pair) {
        pair = new MockPair(a, b);
        getPair[a][b] = address(pair);
        getPair[b][a] = address(pair);
    }
}

contract SwapRouterTest is Test {
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    MockERC20 public tokenC;
    MockFactory public factory;
    MockPair public pairAB;
    MockPair public pairBC;
    SwapRouter public router;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        tokenA = new MockERC20();
        tokenB = new MockERC20();
        tokenC = new MockERC20();
        factory = new MockFactory();
        router = new SwapRouter(address(factory));
        pairAB = factory.createPair(address(tokenA), address(tokenB));
        pairBC = factory.createPair(address(tokenB), address(tokenC));
        tokenA.mint(address(pairAB), 100_000 ether);
        tokenB.mint(address(pairAB), 200_000 ether);
        pairAB.sync();
        tokenB.mint(address(pairBC), 50_000 ether);
        tokenC.mint(address(pairBC), 150_000 ether);
        pairBC.sync();
        tokenA.mint(alice, 10_000 ether);
        vm.prank(alice);
        tokenA.approve(address(router), type(uint256).max);
    }

    function _out(uint256 amountIn, uint256 rIn, uint256 rOut) internal pure returns (uint256) {
        return (amountIn * 997 * rOut) / (rIn * 1000 + amountIn * 997);
    }

    function _path2(address a, address b) internal pure returns (address[] memory p) {
        p = new address[](2);
        (p[0], p[1]) = (a, b);
    }

    function _path3(address a, address b, address c) internal pure returns (address[] memory p) {
        p = new address[](3);
        (p[0], p[1], p[2]) = (a, b, c);
    }

    function testGetAmountOutFormula() public view {
        assertEq(router.getAmountOut(1000, 100_000, 100_000), 987);
        assertEq(router.getAmountOut(1 ether, 100 ether, 400 ether), _out(1 ether, 100 ether, 400 ether));
    }

    function testGetAmountsOutTwoHops() public view {
        uint256[] memory amounts =
            router.getAmountsOut(100 ether, _path3(address(tokenA), address(tokenB), address(tokenC)));
        assertEq(amounts.length, 3);
        assertEq(amounts[0], 100 ether);
        uint256 b = _out(100 ether, 100_000 ether, 200_000 ether);
        assertEq(amounts[1], b);
        assertEq(amounts[2], _out(b, 50_000 ether, 150_000 ether));
    }

    function testSingleHopSwap() public {
        uint256 expected = _out(100 ether, 100_000 ether, 200_000 ether);
        vm.prank(alice);
        uint256[] memory amounts = router.swapExactTokensForTokens(
            100 ether, expected, _path2(address(tokenA), address(tokenB)), bob, block.timestamp
        );
        assertEq(amounts[1], expected);
        assertEq(tokenB.balanceOf(bob), expected);
        assertEq(tokenA.balanceOf(alice), 9_900 ether);
        assertEq(tokenA.balanceOf(address(pairAB)), 100_100 ether);
    }

    function testTwoHopSwap() public {
        uint256 b = _out(100 ether, 100_000 ether, 200_000 ether);
        uint256 c = _out(b, 50_000 ether, 150_000 ether);
        vm.prank(alice);
        router.swapExactTokensForTokens(
            100 ether, 0, _path3(address(tokenA), address(tokenB), address(tokenC)), alice, block.timestamp + 60
        );
        assertEq(tokenC.balanceOf(alice), c);
        assertEq(tokenB.balanceOf(alice), 0);
        assertEq(tokenB.balanceOf(address(router)), 0);
        assertEq(tokenB.balanceOf(address(pairBC)), 50_000 ether + b);
    }

    function testMinimumOutputEnforced() public {
        uint256 expected = _out(100 ether, 100_000 ether, 200_000 ether);
        address[] memory path = _path2(address(tokenA), address(tokenB));
        vm.prank(alice);
        vm.expectRevert(SwapRouter.InsufficientOutputAmount.selector);
        router.swapExactTokensForTokens(100 ether, expected + 1, path, alice, block.timestamp);
    }

    function testDeadlineEnforced() public {
        address[] memory path = _path2(address(tokenA), address(tokenB));
        uint256 deadline = block.timestamp + 10;
        vm.warp(block.timestamp + 11);
        vm.prank(alice);
        vm.expectRevert(SwapRouter.Expired.selector);
        router.swapExactTokensForTokens(100 ether, 0, path, alice, deadline);
    }
}
