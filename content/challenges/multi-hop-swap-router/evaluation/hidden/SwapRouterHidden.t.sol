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

contract SwapRouterHiddenTest is Test {
    MockERC20[4] public tokens;
    MockFactory public factory;
    MockPair[3] public pairs; // (0,1), (1,2), (2,3)
    SwapRouter public router;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    uint256[2][3] internal liq;

    function setUp() public {
        for (uint256 i = 0; i < 4; i++) {
            tokens[i] = new MockERC20();
        }
        factory = new MockFactory();
        router = new SwapRouter(address(factory));
        liq[0] = [uint256(80_000 ether + 17), 31_000 ether + 5];
        liq[1] = [uint256(12_345 ether), 67_890 ether + 1];
        liq[2] = [uint256(1_000_000 ether), 999 ether + 3];
        for (uint256 i = 0; i < 3; i++) {
            pairs[i] = factory.createPair(address(tokens[i]), address(tokens[i + 1]));
            tokens[i].mint(address(pairs[i]), liq[i][0]);
            tokens[i + 1].mint(address(pairs[i]), liq[i][1]);
            pairs[i].sync();
        }
        for (uint256 i = 0; i < 4; i++) {
            tokens[i].mint(alice, 1_000 ether);
            vm.prank(alice);
            tokens[i].approve(address(router), type(uint256).max);
        }
    }

    function _out(uint256 amountIn, uint256 rIn, uint256 rOut) internal pure returns (uint256) {
        return (amountIn * 997 * rOut) / (rIn * 1000 + amountIn * 997);
    }

    function _path(uint256[] memory idx) internal view returns (address[] memory p) {
        p = new address[](idx.length);
        for (uint256 i = 0; i < idx.length; i++) {
            p[i] = address(tokens[idx[i]]);
        }
    }

    function _idx2(uint256 a, uint256 b) internal pure returns (uint256[] memory r) {
        r = new uint256[](2);
        (r[0], r[1]) = (a, b);
    }

    function _assertSynced() internal view {
        for (uint256 i = 0; i < 3; i++) {
            (uint256 r0, uint256 r1) = pairs[i].getReserves();
            assertEq(r0, MockERC20(pairs[i].token0()).balanceOf(address(pairs[i])), "reserve0 != balance");
            assertEq(r1, MockERC20(pairs[i].token1()).balanceOf(address(pairs[i])), "reserve1 != balance");
        }
        for (uint256 i = 0; i < 4; i++) {
            assertEq(tokens[i].balanceOf(address(router)), 0, "router holds tokens");
        }
    }

    function testHiddenThreeHopForward() public {
        uint256[] memory idx = new uint256[](4);
        (idx[0], idx[1], idx[2], idx[3]) = (0, 1, 2, 3);
        uint256 a1 = _out(7 ether + 3, liq[0][0], liq[0][1]);
        uint256 a2 = _out(a1, liq[1][0], liq[1][1]);
        uint256 a3 = _out(a2, liq[2][0], liq[2][1]);
        address[] memory path = _path(idx);
        uint256[] memory quoted = router.getAmountsOut(7 ether + 3, path);
        assertEq(quoted[3], a3);
        vm.prank(alice);
        uint256[] memory amounts = router.swapExactTokensForTokens(7 ether + 3, a3, path, bob, block.timestamp);
        assertEq(amounts.length, 4);
        assertEq(amounts[1], a1);
        assertEq(amounts[2], a2);
        assertEq(amounts[3], a3);
        assertEq(tokens[3].balanceOf(bob), a3);
        assertEq(tokens[1].balanceOf(bob), 0);
        assertEq(tokens[2].balanceOf(bob), 0);
        assertEq(tokens[3].balanceOf(alice), 1_000 ether);
        assertEq(tokens[0].balanceOf(alice), 1_000 ether - (7 ether + 3));
        _assertSynced();
    }

    function testHiddenThreeHopReverse() public {
        uint256[] memory idx = new uint256[](4);
        (idx[0], idx[1], idx[2], idx[3]) = (3, 2, 1, 0);
        uint256 a1 = _out(0.5 ether, liq[2][1], liq[2][0]);
        uint256 a2 = _out(a1, liq[1][1], liq[1][0]);
        uint256 a3 = _out(a2, liq[0][1], liq[0][0]);
        vm.prank(alice);
        router.swapExactTokensForTokens(0.5 ether, a3, _path(idx), alice, block.timestamp + 1);
        assertEq(tokens[0].balanceOf(alice), 1_000 ether + a3);
        _assertSynced();
    }

    function testHiddenBothDirectionsOfOnePair() public {
        uint256 out01 = _out(10 ether, liq[0][0], liq[0][1]);
        vm.prank(alice);
        router.swapExactTokensForTokens(10 ether, 0, _path(_idx2(0, 1)), alice, block.timestamp);
        assertEq(tokens[1].balanceOf(alice), 1_000 ether + out01);
        uint256 out10 = _out(out01, liq[0][1] - out01, liq[0][0] + 10 ether);
        assertEq(router.getAmountsOut(out01, _path(_idx2(1, 0)))[1], out10);
        vm.prank(alice);
        router.swapExactTokensForTokens(out01, out10, _path(_idx2(1, 0)), alice, block.timestamp);
        // the round trip loses the two fees
        assertEq(tokens[0].balanceOf(alice), 1_000 ether - 10 ether + out10);
        assertLt(out10, 10 ether);
        _assertSynced();
    }

    function testHiddenDeadlineBoundaryAndOrder() public {
        address[] memory path = _path(_idx2(0, 1));
        uint256 deadline = block.timestamp + 100;
        vm.warp(deadline);
        vm.prank(alice);
        router.swapExactTokensForTokens(1 ether, 0, path, alice, deadline);
        vm.warp(deadline + 1);
        vm.prank(alice);
        vm.expectRevert(SwapRouter.Expired.selector);
        router.swapExactTokensForTokens(1 ether, 0, path, alice, deadline);
        // an expired call with an invalid path still reports Expired
        vm.prank(alice);
        vm.expectRevert(SwapRouter.Expired.selector);
        router.swapExactTokensForTokens(1 ether, 0, new address[](1), alice, deadline);
    }

    function testHiddenPathValidation() public {
        address[] memory one = new address[](1);
        one[0] = address(tokens[0]);
        vm.expectRevert(SwapRouter.InvalidPath.selector);
        router.getAmountsOut(1 ether, one);
        vm.expectRevert(SwapRouter.InvalidPath.selector);
        router.getAmountsOut(1 ether, new address[](0));
        vm.prank(alice);
        vm.expectRevert(SwapRouter.InvalidPath.selector);
        router.swapExactTokensForTokens(1 ether, 0, one, alice, block.timestamp);
        // tokens 0 and 2 have no direct pair
        vm.expectRevert(SwapRouter.PairNotFound.selector);
        router.getAmountsOut(1 ether, _path(_idx2(0, 2)));
        vm.prank(alice);
        vm.expectRevert(SwapRouter.PairNotFound.selector);
        router.swapExactTokensForTokens(1 ether, 0, _path(_idx2(0, 2)), alice, block.timestamp);
        assertEq(tokens[0].balanceOf(alice), 1_000 ether);
    }

    function testHiddenQuoteValidation() public {
        vm.expectRevert(SwapRouter.ZeroAmount.selector);
        router.getAmountOut(0, 1 ether, 1 ether);
        vm.expectRevert(SwapRouter.InsufficientLiquidity.selector);
        router.getAmountOut(1 ether, 0, 1 ether);
        vm.expectRevert(SwapRouter.InsufficientLiquidity.selector);
        router.getAmountOut(1 ether, 1 ether, 0);
        vm.prank(alice);
        vm.expectRevert(SwapRouter.ZeroAmount.selector);
        router.swapExactTokensForTokens(0, 0, _path(_idx2(0, 1)), alice, block.timestamp);
        // dust that rounds to zero output on the second hop cannot be swapped
        assertEq(router.getAmountOut(1, 1_000_000 ether, 999 ether), 0);
    }

    function testHiddenExactMinimumPassesAndNoAllowanceFails() public {
        address[] memory path = _path(_idx2(2, 3));
        uint256 expected = _out(3 ether, liq[2][0], liq[2][1]);
        vm.prank(alice);
        vm.expectRevert(SwapRouter.InsufficientOutputAmount.selector);
        router.swapExactTokensForTokens(3 ether, expected + 1, path, alice, block.timestamp);
        vm.prank(alice);
        router.swapExactTokensForTokens(3 ether, expected, path, alice, block.timestamp);
        assertEq(tokens[3].balanceOf(alice), 1_000 ether + expected);

        tokens[2].mint(bob, 10 ether); // bob never approved the router
        vm.prank(bob);
        vm.expectRevert();
        router.swapExactTokensForTokens(1 ether, 0, path, bob, block.timestamp);
        assertEq(tokens[2].balanceOf(bob), 10 ether);
        _assertSynced();
    }
}
