// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SimpleAMM.sol";

contract MockTokenH {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function mint(address to, uint256 amount) external { balanceOf[to] += amount; }
    function approve(address spender, uint256 amount) external returns (bool) { allowance[msg.sender][spender] = amount; return true; }
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount; balanceOf[to] += amount; return true;
    }
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount; balanceOf[from] -= amount; balanceOf[to] += amount; return true;
    }
}

contract SimpleAMMHiddenTest is Test {
    MockTokenH public t0;
    MockTokenH public t1;
    SimpleAMM public amm;
    address public lp = address(0x111);

    function setUp() public {
        t0 = new MockTokenH();
        t1 = new MockTokenH();
        amm = new SimpleAMM(address(t0), address(t1));
        t0.mint(lp, 10_000 ether);
        t1.mint(lp, 10_000 ether);
        vm.prank(lp); t0.approve(address(amm), type(uint256).max);
        vm.prank(lp); t1.approve(address(amm), type(uint256).max);
    }

    function testHiddenRejectsInvalidTokenSwap() public {
        vm.prank(lp);
        amm.addLiquidity(100 ether, 100 ether);
        vm.expectRevert();
        amm.swap(address(0xDEAD), 10 ether);
    }

    function testHiddenRejectsZeroAmountSwap() public {
        vm.prank(lp);
        amm.addLiquidity(100 ether, 100 ether);
        vm.expectRevert();
        amm.swap(address(t0), 0);
    }
}
