// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/SwapRouterGuard.sol";

contract SandwichedPool {
    uint256 public nextOut = 950;
    function setOut(uint256 o) external { nextOut = o; }
    function swap(uint256) external view returns (uint256) { return nextOut; }
}

contract SwapRouterGuardTest is Test {
    SandwichedPool public pool;
    SwapRouterGuard public router;

    function setUp() public {
        pool = new SandwichedPool();
        router = new SwapRouterGuard(address(pool));
    }

    function testSandwichSlippageReverts() public {
        pool.setOut(400);
        vm.expectRevert();
        router.swapExactIn(1000, 900, block.timestamp + 60);
    }

    function testExpiredTransactionReverts() public {
        uint256 dl = block.timestamp + 10;
        vm.warp(dl + 1);
        vm.expectRevert();
        router.swapExactIn(1000, 900, dl);
    }
}