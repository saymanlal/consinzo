// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SimpleAMM.sol";

contract MockToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function mint(address to, uint256 amount) external { balanceOf[to] += amount; }
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "BAL");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(allowance[from][msg.sender] >= amount, "ALLOW");
        require(balanceOf[from] >= amount, "BAL");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract SimpleAMMTest is Test {
    MockToken public t0;
    MockToken public t1;
    SimpleAMM public amm;
    address public lp = address(0x111);
    address public trader = address(0x222);

    function setUp() public {
        t0 = new MockToken();
        t1 = new MockToken();
        amm = new SimpleAMM(address(t0), address(t1));

        t0.mint(lp, 10_000 ether);
        t1.mint(lp, 10_000 ether);
        t0.mint(trader, 1_000 ether);

        vm.prank(lp);
        t0.approve(address(amm), type(uint256).max);
        vm.prank(lp);
        t1.approve(address(amm), type(uint256).max);
        vm.prank(trader);
        t0.approve(address(amm), type(uint256).max);
    }

    function testAddAndRemoveLiquidity() public {
        vm.prank(lp);
        uint256 minted = amm.addLiquidity(1_000 ether, 4_000 ether);
        assertEq(minted, 2_000 ether);
        assertEq(amm.reserve0(), 1_000 ether);
        assertEq(amm.reserve1(), 4_000 ether);

        vm.prank(lp);
        (uint256 a0, uint256 a1) = amm.removeLiquidity(1_000 ether);
        assertEq(a0, 500 ether);
        assertEq(a1, 2_000 ether);
    }

    function testSwapPreservesKInvariant() public {
        vm.prank(lp);
        amm.addLiquidity(1_000 ether, 1_000 ether);
        uint256 kBefore = amm.reserve0() * amm.reserve1();

        vm.prank(trader);
        uint256 out = amm.swap(address(t0), 100 ether);
        assertGt(out, 0);
        assertLt(out, 100 ether);
        assertGe(amm.reserve0() * amm.reserve1(), kBefore);
        assertEq(t1.balanceOf(trader), out);
    }
}
