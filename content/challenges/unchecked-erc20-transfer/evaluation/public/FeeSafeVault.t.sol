// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/FeeSafeVault.sol";

contract FeeToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function mint(address to, uint256 amt) external { balanceOf[to] += amt; }
    function approve(address s, uint256 amt) external returns (bool) { allowance[msg.sender][s] = amt; return true; }
    function transfer(address to, uint256 amt) external returns (bool) {
        balanceOf[msg.sender] -= amt;
        uint256 fee = amt / 10;
        balanceOf[to] += (amt - fee);
        return true;
    }
    function transferFrom(address f, address t, uint256 amt) external returns (bool) {
        allowance[f][msg.sender] -= amt;
        balanceOf[f] -= amt;
        uint256 fee = amt / 10;
        balanceOf[t] += (amt - fee);
        return true;
    }
}

contract FeeSafeVaultTest is Test {
    function testCreditsActualReceivedDelta() public {
        FeeToken t = new FeeToken();
        FeeSafeVault v = new FeeSafeVault(address(t));
        address alice = address(0xA11CE);
        t.mint(alice, 1000);
        vm.prank(alice); t.approve(address(v), 1000);
        vm.prank(alice); v.deposit(1000);
        assertEq(v.balances(alice), 900);
        vm.prank(alice); v.withdraw(900);
        assertEq(v.balances(alice), 0);
    }
}