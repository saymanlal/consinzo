// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/FeeSafeVault.sol";

contract ZeroDeltaToken {
    function balanceOf(address) external pure returns (uint256) { return 0; }
    function transfer(address, uint256) external pure returns (bool) { return true; }
    function transferFrom(address, address, uint256) external pure returns (bool) { return true; }
}

contract FeeSafeVaultHiddenTest is Test {
    function testHiddenZeroReceivedReverts() public {
        ZeroDeltaToken t = new ZeroDeltaToken();
        FeeSafeVault v = new FeeSafeVault(address(t));
        vm.expectRevert();
        v.deposit(100);
    }
}