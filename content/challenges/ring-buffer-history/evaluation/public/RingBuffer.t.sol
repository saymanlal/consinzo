// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RingBuffer.sol";

contract RingBufferTest is Test {
    RingBuffer public buffer;

    function setUp() public {
        buffer = new RingBuffer(3);
    }

    function testInitialState() public view {
        assertEq(buffer.capacity(), 3);
        assertEq(buffer.length(), 0);
        assertEq(buffer.totalPushed(), 0);
    }

    function testPushBelowCapacity() public {
        buffer.push(10);
        buffer.push(20);
        assertEq(buffer.length(), 2);
        assertEq(buffer.at(0), 10);
        assertEq(buffer.at(1), 20);
        assertEq(buffer.latest(), 20);
        assertEq(buffer.oldest(), 10);
    }

    function testOverwritesOldest() public {
        buffer.push(10);
        buffer.push(20);
        buffer.push(30);
        buffer.push(40);
        assertEq(buffer.length(), 3);
        assertEq(buffer.totalPushed(), 4);
        assertEq(buffer.at(0), 20);
        assertEq(buffer.at(1), 30);
        assertEq(buffer.at(2), 40);
    }

    function testToArrayIsChronological() public {
        for (uint256 v = 10; v <= 50; v += 10) {
            buffer.push(v);
        }
        uint256[] memory values = buffer.toArray();
        assertEq(values.length, 3);
        assertEq(values[0], 30);
        assertEq(values[1], 40);
        assertEq(values[2], 50);
    }

    function testAtOutOfBoundsReverts() public {
        buffer.push(1);
        vm.expectRevert(abi.encodeWithSelector(RingBuffer.IndexOutOfBounds.selector, uint256(1), uint256(1)));
        buffer.at(1);
    }
}
