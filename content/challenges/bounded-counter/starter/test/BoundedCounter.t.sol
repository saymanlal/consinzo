// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BoundedCounter.sol";

contract BoundedCounterTest is Test {
    BoundedCounter public counter;

    function setUp() public {
        counter = new BoundedCounter(2, 5, 3);
    }

    function testInitialState() public view {
        assertEq(counter.min(), 2);
        assertEq(counter.max(), 5);
        assertEq(counter.value(), 3);
    }

    function testIncrementAndDecrement() public {
        counter.increment();
        assertEq(counter.value(), 4);
        counter.decrement();
        counter.decrement();
        assertEq(counter.value(), 2);
    }

    function testCannotExceedMax() public {
        counter.add(2);
        assertEq(counter.value(), 5);
        vm.expectRevert(abi.encodeWithSelector(BoundedCounter.AboveMax.selector, uint256(5)));
        counter.increment();
        assertEq(counter.value(), 5);
    }

    function testCannotDropBelowMin() public {
        counter.sub(1);
        assertEq(counter.value(), 2);
        vm.expectRevert(abi.encodeWithSelector(BoundedCounter.BelowMin.selector, uint256(2)));
        counter.decrement();
        assertEq(counter.value(), 2);
    }
}
