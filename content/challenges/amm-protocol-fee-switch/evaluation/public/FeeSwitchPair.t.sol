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

contract FeeSwitchPairTest is Test {
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

    function testInitialMintLocksMinimumLiquidity() public {
        uint256 liquidity = pair.mint(1_000 ether, 1_000 ether, address(this));
        assertEq(liquidity, 1_000 ether - 1000);
        assertEq(pair.balanceOf(address(this)), 1_000 ether - 1000);
        assertEq(pair.balanceOf(address(0)), 1000);
        assertEq(pair.totalSupply(), 1_000 ether);
        assertEq(pair.reserve0(), 1_000 ether);
        assertEq(pair.reserve1(), 1_000 ether);
        assertEq(pair.kLast(), 0);
    }

    function testSwapChargesThirtyBps() public {
        pair.mint(1_000 ether, 1_000 ether, address(this));
        uint256 out = _swap0(100 ether);
        assertEq(out, 90661089388014913158);
        assertEq(t1.balanceOf(trader), 1_000 ether + 90661089388014913158);
        assertEq(pair.reserve0(), 1_100 ether);
        assertEq(pair.reserve1(), 909338910611985086842);
    }

    function testFeeOffMintsNoProtocolShares() public {
        pair.mint(1_000 ether, 1_000 ether, address(this));
        _swap0(100 ether);
        (uint256 a0, uint256 a1) = pair.burn(500 ether, address(this));
        assertEq(a0, 550 ether);
        assertEq(a1, 454669455305992543421);
        assertEq(pair.totalSupply(), 500 ether);
        assertEq(pair.balanceOf(feeTo), 0);
        assertEq(pair.kLast(), 0);
    }

    function testFeeOnRecordsKLast() public {
        pair.setFeeTo(feeTo);
        assertEq(pair.feeTo(), feeTo);
        pair.mint(1_000 ether, 1_000 ether, address(this));
        assertEq(pair.kLast(), 1_000 ether * 1_000 ether);
        _swap0(100 ether);
        // swaps never touch kLast
        assertEq(pair.kLast(), 1_000 ether * 1_000 ether);
        assertEq(pair.balanceOf(feeTo), 0);
    }

    function testFeeOnMintsSharesOnBurn() public {
        pair.setFeeTo(feeTo);
        pair.mint(1_000 ether, 1_000 ether, address(this));
        _swap0(100 ether);
        (uint256 a0, uint256 a1) = pair.burn(500 ether, address(this));
        // rootK = 1000136391535266351606, rootKLast = 1000e18
        assertEq(pair.balanceOf(feeTo), 22729339136508252);
        // payout is computed against the diluted supply
        assertEq(a0, 549987499147611033905);
        assertEq(a1, 454659121204635176457);
        assertEq(pair.totalSupply(), 500022729339136508252);
        assertEq(pair.kLast(), pair.reserve0() * pair.reserve1());
        assertEq(pair.kLast(), 250079568058974078182853135406961053396575);
    }

    function testOnlyOwnerSetsFeeTo() public {
        vm.prank(trader);
        vm.expectRevert(FeeSwitchPair.NotOwner.selector);
        pair.setFeeTo(trader);
    }
}
