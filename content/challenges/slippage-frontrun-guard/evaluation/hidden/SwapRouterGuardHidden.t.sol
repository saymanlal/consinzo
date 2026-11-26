// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/SwapRouterGuard.sol";

contract SandwichedPoolH {
    function swap(uint256) external pure returns (uint256) { return 950; }
}

contract SwapRouterGuardHiddenTest is Test {
    function testHiddenZeroMinOutRejected() public {
        SandwichedPoolH p = new SandwichedPoolH();
        SwapRouterGuard r = new SwapRouterGuard(address(p));
        vm.expectRevert();
        r.swapExactIn(1000, 0, block.timestamp + 60);
    }
}