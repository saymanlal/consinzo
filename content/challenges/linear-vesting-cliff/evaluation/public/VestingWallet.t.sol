// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/VestingWallet.sol";

contract VestingWalletTest is Test {
    address public alice = address(0xA11CE);
    VestingWallet public w;

    function setUp() public {
        w = new VestingWallet{value: 10 ether}(alice, block.timestamp, 100, 1000);
    }

    function testZeroBeforeCliffAndHalfAtMidpoint() public {
        assertEq(w.vestedAmount(block.timestamp + 50), 0);
        vm.warp(block.timestamp + 500);
        assertEq(w.vestedAmount(block.timestamp), 5 ether);
        vm.prank(alice);
        uint256 out = w.release();
        assertEq(out, 5 ether);
        assertEq(alice.balance, 5 ether);
    }
}