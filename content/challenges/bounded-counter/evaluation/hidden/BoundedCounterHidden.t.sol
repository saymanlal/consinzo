// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BoundedCounter.sol";

contract BoundedCounterHiddenTest is Test {
    function testHiddenConstructorRejectsInvertedBounds() public {
        try new BoundedCounter(6, 5, 5) {
            assertTrue(false, "inverted bounds accepted");
        } catch (bytes memory data) {
            assertEq(
                keccak256(data),
                keccak256(abi.encodeWithSelector(BoundedCounter.InvalidBounds.selector, uint256(6), uint256(5)))
            );
        }
    }

    function testHiddenConstructorRejectsInitialOutside() public {
        try new BoundedCounter(10, 20, 9) {
            assertTrue(false, "initial below min accepted");
        } catch (bytes memory data) {
            assertEq(
                keccak256(data),
                keccak256(abi.encodeWithSelector(BoundedCounter.InitialOutOfBounds.selector, uint256(9)))
            );
        }
        try new BoundedCounter(10, 20, 21) {
            assertTrue(false, "initial above max accepted");
        } catch (bytes memory data) {
            assertEq(
                keccak256(data),
                keccak256(abi.encodeWithSelector(BoundedCounter.InitialOutOfBounds.selector, uint256(21)))
            );
        }
    }

    function testHiddenInitialOnBoundsAccepted() public {
        BoundedCounter low = new BoundedCounter(10, 20, 10);
        BoundedCounter high = new BoundedCounter(10, 20, 20);
        assertEq(low.value(), 10);
        assertEq(high.value(), 20);
    }

    function testHiddenLargeAddRevertsWithCustomError() public {
        BoundedCounter c = new BoundedCounter(0, 100, 50);
        vm.expectRevert(abi.encodeWithSelector(BoundedCounter.AboveMax.selector, uint256(100)));
        c.add(type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(BoundedCounter.AboveMax.selector, uint256(100)));
        c.add(51);
        c.add(50);
        assertEq(c.value(), 100);
    }

    function testHiddenLargeSubRevertsWithCustomError() public {
        BoundedCounter c = new BoundedCounter(10, 100, 50);
        vm.expectRevert(abi.encodeWithSelector(BoundedCounter.BelowMin.selector, uint256(10)));
        c.sub(51);
        vm.expectRevert(abi.encodeWithSelector(BoundedCounter.BelowMin.selector, uint256(10)));
        c.sub(type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(BoundedCounter.BelowMin.selector, uint256(10)));
        c.sub(41);
        c.sub(40);
        assertEq(c.value(), 10);
    }

    function testHiddenFullRangeCounter() public {
        BoundedCounter c = new BoundedCounter(0, type(uint256).max, 1);
        vm.expectRevert(abi.encodeWithSelector(BoundedCounter.AboveMax.selector, type(uint256).max));
        c.add(type(uint256).max);
        c.add(type(uint256).max - 1);
        assertEq(c.value(), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(BoundedCounter.AboveMax.selector, type(uint256).max));
        c.increment();
        c.sub(type(uint256).max);
        assertEq(c.value(), 0);
        vm.expectRevert(abi.encodeWithSelector(BoundedCounter.BelowMin.selector, uint256(0)));
        c.decrement();
    }

    function testHiddenEqualBoundsNeverMove() public {
        BoundedCounter c = new BoundedCounter(7, 7, 7);
        vm.expectRevert(BoundedCounter.AboveMax.selector);
        c.increment();
        vm.expectRevert(BoundedCounter.BelowMin.selector);
        c.decrement();
        c.add(0);
        c.sub(0);
        assertEq(c.value(), 7);
    }
}
