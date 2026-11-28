// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FeeSwitchPair.sol";

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

contract FeeSwitchPairHiddenTest is Test {
    MockERC20 public t0;
    MockERC20 public t1;
    FeeSwitchPair public pair;
    address public feeTo = address(0xFEE);
    address public trader = address(0x7EAD);

    function setUp() public {
        t0 = new MockERC20();
        t1 = new MockERC20();
        pair = new FeeSwitchPair(address(t0), address(t1));
        t0.mint(address(this), 10_000 ether);
        t1.mint(address(this), 10_000 ether);
        t0.approve(address(pair), type(uint256).max);
        t1.approve(address(pair), type(uint256).max);
        t0.mint(trader, 1_000 ether);
        t1.mint(trader, 1_000 ether);
        vm.prank(trader);
        t0.approve(address(pair), type(uint256).max);
        vm.prank(trader);
        t1.approve(address(pair), type(uint256).max);
    }

    function _swap0(uint256 amountIn) internal returns (uint256 out) {
        vm.prank(trader);
        out = pair.swap(address(t0), amountIn, 0, trader);
    }

    function _swap1(uint256 amountIn) internal returns (uint256 out) {
        vm.prank(trader);
        out = pair.swap(address(t1), amountIn, 0, trader);
    }

    function _assertReservesMatchBalances() internal view {
        assertEq(pair.reserve0(), t0.balanceOf(address(pair)));
        assertEq(pair.reserve1(), t1.balanceOf(address(pair)));
    }

    function testHiddenFeeOnMintPathDilutesBeforeMinting() public {
        pair.setFeeTo(feeTo);
        pair.mint(1_000 ether, 1_000 ether, address(this));
        _swap0(100 ether);
        uint256 liquidity = pair.mint(110 ether, 90933891061198508685, address(0xCAFE));
        assertEq(pair.balanceOf(feeTo), 22729339136508252);
        assertEq(liquidity, 100002272933913650825);
        assertEq(pair.balanceOf(address(0xCAFE)), 100002272933913650825);
        assertEq(pair.kLast(), pair.reserve0() * pair.reserve1());
        _assertReservesMatchBalances();
    }

    function testHiddenFeeOffMintPathUsesUndilutedSupply() public {
        pair.mint(1_000 ether, 1_000 ether, address(this));
        _swap0(100 ether);
        uint256 liquidity = pair.mint(110 ether, 90933891061198508685, address(0xCAFE));
        assertEq(liquidity, 100 ether);
        assertEq(pair.totalSupply(), 1_100 ether);
        assertEq(pair.kLast(), 0);
    }

    function testHiddenNoGrowthMintsNothing() public {
        pair.setFeeTo(feeTo);
        pair.mint(1_000 ether, 1_000 ether, address(this));
        pair.mint(500 ether, 500 ether, address(this));
        pair.burn(300 ether, address(this));
        pair.burn(1 ether, address(this));
        assertEq(pair.balanceOf(feeTo), 0);
        assertEq(pair.totalSupply(), 1_199 ether);
        assertEq(pair.kLast(), 1_199 ether * 1_199 ether);
    }

    function testHiddenGrowthBeforeSwitchOnIsNotCharged() public {
        pair.mint(1_000 ether, 1_000 ether, address(this));
        _swap0(100 ether);
        pair.setFeeTo(feeTo);
        // setFeeTo itself records nothing
        assertEq(pair.kLast(), 0);
        (uint256 a0, uint256 a1) = pair.burn(500 ether, address(this));
        assertEq(a0, 550 ether);
        assertEq(a1, 454669455305992543421);
        assertEq(pair.balanceOf(feeTo), 0);
        assertEq(pair.kLast(), 250068200418295898881550000000000000000000);

        // growth after the switch is charged
        uint256 out = _swap1(50 ether);
        assertEq(out, 54343791327871003651);
        (a0, a1) = pair.burn(100 ether, address(this));
        assertEq(pair.balanceOf(feeTo), 12385570886733548);
        assertEq(a0, 99128786201208977413);
        assertEq(a1, 100931390875405740785);
        _assertReservesMatchBalances();
    }

    function testHiddenSwitchOffResetsKLastAndSkipsFee() public {
        pair.setFeeTo(feeTo);
        pair.mint(1_000 ether, 1_000 ether, address(this));
        _swap0(100 ether);
        pair.setFeeTo(address(0));
        assertEq(pair.kLast(), 1_000 ether * 1_000 ether);
        (uint256 a0, uint256 a1) = pair.burn(500 ether, address(this));
        assertEq(a0, 550 ether);
        assertEq(a1, 454669455305992543421);
        assertEq(pair.balanceOf(feeTo), 0);
        assertEq(pair.kLast(), 0);

        // turning it back on must not charge the old growth
        pair.setFeeTo(feeTo);
        pair.burn(100 ether, address(this));
        assertEq(pair.balanceOf(feeTo), 0);
        assertEq(pair.kLast(), pair.reserve0() * pair.reserve1());
    }

    function testHiddenFeeRecipientCanRedeem() public {
        pair.setFeeTo(feeTo);
        pair.mint(1_000 ether, 1_000 ether, address(this));
        _swap0(100 ether);
        pair.burn(500 ether, address(this));
        vm.prank(feeTo);
        (uint256 a0, uint256 a1) = pair.burn(22729339136508252, feeTo);
        assertEq(a0, 25001704777932188);
        assertEq(a1, 20668202714733926);
        assertEq(t0.balanceOf(feeTo), 25001704777932188);
        assertEq(t1.balanceOf(feeTo), 20668202714733926);
        assertEq(pair.balanceOf(feeTo), 0);
        assertEq(pair.totalSupply(), 500 ether);
        _assertReservesMatchBalances();
    }

    function testHiddenProtocolShareIsOneSixthOfGrowth() public {
        pair.setFeeTo(feeTo);
        pair.mint(1_000 ether, 1_000 ether, address(this));
        for (uint256 i = 0; i < 5; i++) {
            _swap0(40 ether);
            _swap1(40 ether);
        }
        uint256 rootK = pair.reserve0() * pair.reserve1();
        pair.burn(1 ether, address(this));
        uint256 feeShares = pair.balanceOf(feeTo);
        assertGt(feeShares, 0);
        // The LP position grew by g = rootK/rootKLast - 1 per share. The recipient's stake of
        // the pool, feeShares / supply, must equal one sixth of g / (1 + g), within rounding.
        uint256 supply = pair.totalSupply() + 1 ether;
        uint256 root = _sqrt(rootK);
        uint256 expected = (1_000 ether * (root - 1_000 ether)) / (root * 5 + 1_000 ether);
        assertEq(feeShares, expected);
        assertEq(supply, 1_000 ether + expected);
        // six times the recipient's stake is the whole fee growth, to within 1e-12 relative
        uint256 lhs = feeShares * 6 * root;
        uint256 rhs = supply * (root - 1_000 ether);
        uint256 diff = lhs > rhs ? lhs - rhs : rhs - lhs;
        assertLt(diff, rhs / 1e12);
    }

    function testHiddenReverts() public {
        vm.expectRevert(FeeSwitchPair.InsufficientLiquidityMinted.selector);
        pair.mint(1000, 1000, address(this));

        pair.mint(1_000 ether, 1_000 ether, address(this));

        vm.expectRevert(FeeSwitchPair.InsufficientLiquidityMinted.selector);
        pair.mint(1 ether, 0, address(this));

        vm.expectRevert(FeeSwitchPair.ZeroAmount.selector);
        pair.burn(0, address(this));

        vm.expectRevert(FeeSwitchPair.InsufficientLiquidity.selector);
        pair.burn(1_000 ether, address(this));

        vm.prank(trader);
        vm.expectRevert(FeeSwitchPair.InvalidToken.selector);
        pair.swap(address(0xDEAD), 1 ether, 0, trader);

        vm.prank(trader);
        vm.expectRevert(FeeSwitchPair.ZeroAmount.selector);
        pair.swap(address(t0), 0, 0, trader);

        vm.prank(trader);
        vm.expectRevert(FeeSwitchPair.InsufficientOutput.selector);
        pair.swap(address(t0), 100 ether, 90661089388014913159, trader);

        vm.prank(trader);
        vm.expectRevert(FeeSwitchPair.InsufficientOutput.selector);
        pair.swap(address(t0), 1, 0, trader);

        vm.prank(trader);
        uint256 out = pair.swap(address(t0), 100 ether, 90661089388014913158, trader);
        assertEq(out, 90661089388014913158);
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
