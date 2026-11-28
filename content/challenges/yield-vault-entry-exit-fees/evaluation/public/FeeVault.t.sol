// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FeeVault.sol";

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

contract FeeVaultTest is Test {
    MockERC20 public token;
    FeeVault public vault;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public treasury = address(0xFEE);

    function setUp() public {
        token = new MockERC20();
        vault = new FeeVault(address(token), 100, 50, treasury); // 1% in, 0.5% out
        token.mint(alice, 10_000 ether);
        token.mint(bob, 10_000 ether);
        token.mint(address(this), 10_000 ether);
        token.approve(address(vault), type(uint256).max);
        vm.prank(alice);
        token.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        token.approve(address(vault), type(uint256).max);
    }

    function testFirstDepositChargesFee() public {
        (uint256 previewShares, uint256 previewFee) = vault.previewDeposit(1_000 ether);
        assertEq(previewShares, 990 ether);
        assertEq(previewFee, 10 ether);
        vm.prank(alice);
        uint256 shares = vault.deposit(1_000 ether);
        assertEq(shares, 990 ether);
        assertEq(vault.balanceOf(alice), 990 ether);
        assertEq(vault.totalSupply(), 990 ether);
        assertEq(vault.totalAssets(), 990 ether);
        assertEq(token.balanceOf(treasury), 10 ether);
        assertEq(token.balanceOf(address(vault)), 990 ether);
    }

    function testYieldRaisesSharePrice() public {
        vm.prank(alice);
        vault.deposit(1_000 ether);
        vault.addYield(99 ether);
        assertEq(vault.totalAssets(), 1_089 ether);
        assertEq(vault.convertToAssets(990 ether), 1_089 ether);
        assertEq(vault.convertToAssets(1 ether), 1.1 ether);
    }

    function testDepositAfterYieldGetsFewerShares() public {
        vm.prank(alice);
        vault.deposit(1_000 ether);
        vault.addYield(99 ether);
        vm.prank(bob);
        uint256 shares = vault.deposit(1_000 ether);
        assertEq(shares, 900 ether); // 990 net at 1.1 per share
        assertEq(vault.totalAssets(), 2_079 ether);
        assertEq(token.balanceOf(treasury), 20 ether);
    }

    function testRedeemChargesWithdrawFee() public {
        vm.prank(alice);
        vault.deposit(1_000 ether);
        vault.addYield(99 ether);
        (uint256 previewOut, uint256 previewFee) = vault.previewRedeem(990 ether);
        assertEq(previewFee, 5.445 ether);
        assertEq(previewOut, 1_083.555 ether);
        vm.prank(alice);
        uint256 out = vault.redeem(990 ether);
        assertEq(out, 1_083.555 ether);
        assertEq(token.balanceOf(alice), 9_000 ether + 1_083.555 ether);
        assertEq(token.balanceOf(treasury), 10 ether + 5.445 ether);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalSupply(), 0);
        assertEq(token.balanceOf(address(vault)), 0);
    }

    function testRedeemMoreThanOwnedReverts() public {
        vm.prank(alice);
        vault.deposit(1_000 ether);
        vm.prank(alice);
        vm.expectRevert(FeeVault.InsufficientShares.selector);
        vault.redeem(990 ether + 1);
    }
}
