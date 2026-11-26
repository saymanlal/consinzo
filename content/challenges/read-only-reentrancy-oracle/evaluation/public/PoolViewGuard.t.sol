// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/PoolViewGuard.sol";

contract ReadOnlyObserver {
    PoolViewGuard public pool;
    uint256 public observedPriceDuringCallback;
    constructor(PoolViewGuard p) { pool = p; }
    function trigger() external payable {
        pool.deposit{value: msg.value}();
        pool.withdraw(msg.value);
    }
    receive() external payable {
        observedPriceDuringCallback = pool.sharePrice();
    }
}

contract PoolViewGuardTest is Test {
    function testSharePriceNotSkewedOrAccessibleDuringReentrancy() public {
        PoolViewGuard pool = new PoolViewGuard();
        address lp = address(0xA11CE);
        vm.deal(lp, 5 ether);
        vm.prank(lp); pool.deposit{value: 5 ether}();

        ReadOnlyObserver obs = new ReadOnlyObserver(pool);
        vm.expectRevert();
        obs.trigger{value: 1 ether}();
    }
}