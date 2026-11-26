// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TokenizedVault.sol";

contract MockAssetH {
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

contract TokenizedVaultHiddenTest is Test {
    MockAssetH public usdc;
    TokenizedVault public vault;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        usdc = new MockAssetH();
        vault = new TokenizedVault(address(usdc));
        usdc.mint(alice, 500 ether);
        vm.prank(alice);
        usdc.approve(address(vault), type(uint256).max);
    }

    function testHiddenUnauthorizedRedeemReverts() public {
        vm.prank(alice);
        vault.deposit(100 ether, alice);
        vm.prank(bob);
        vm.expectRevert();
        vault.redeem(50 ether, bob, alice);
    }
}
