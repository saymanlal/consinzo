// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/PoolViewGuard.sol";

contract PoolViewGuardHiddenTest is Test {
    function testHiddenNormalDepositWithdrawAndPrice() public {
        PoolViewGuard p = new PoolViewGuard();
        address u = address(0x111);
        vm.deal(u, 4 ether);
        vm.prank(u); p.deposit{value: 2 ether}();
        assertEq(p.sharePrice(), 1e18);
        vm.prank(u); p.withdraw(2 ether);
        assertEq(p.totalShares(), 0);
    }
}