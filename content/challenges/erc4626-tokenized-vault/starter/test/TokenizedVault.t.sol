// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TokenizedVault.sol";

contract MockAsset {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function mint(address to, uint256 amount) external { balanceOf[to] += amount; }
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount; return true;
    }
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount; balanceOf[to] += amount; return true;
    }
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount; balanceOf[from] -= amount; balanceOf[to] += amount; return true;
    }
}

contract TokenizedVaultTest is Test {
    MockAsset public usdc;
    TokenizedVault public vault;
    address public alice = address(0xA11CE);

    function setUp() public {
        usdc = new MockAsset();
        vault = new TokenizedVault(address(usdc));
        usdc.mint(alice, 1_000 ether);
        vm.prank(alice);
        usdc.approve(address(vault), type(uint256).max);
    }

    function testDepositYieldAndRedeem() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(100 ether, alice);
        assertEq(shares, 100 ether);

        // Simulate 50 ether yield accrued to vault
        usdc.mint(address(vault), 50 ether);
        assertEq(vault.totalAssets(), 150 ether);
        assertEq(vault.convertToAssets(100 ether), 150 ether);

        vm.prank(alice);
        uint256 assetsOut = vault.redeem(shares, alice, alice);
        assertEq(assetsOut, 150 ether);
        assertEq(usdc.balanceOf(alice), 1_050 ether);
    }
}
