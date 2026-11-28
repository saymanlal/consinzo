// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RingBuffer.sol";

contract RingBufferHiddenTest is Test {
    function _assertContents(RingBuffer buffer, uint256[] memory expected) internal view {
        uint256[] memory values = buffer.toArray();
        assertEq(values.length, expected.length);
        assertEq(buffer.length(), expected.length);
        for (uint256 i = 0; i < expected.length; i++) {
            assertEq(values[i], expected[i]);
            assertEq(buffer.at(i), expected[i]);
        }
        if (expected.length > 0) {
            assertEq(buffer.oldest(), expected[0]);
            assertEq(buffer.latest(), expected[expected.length - 1]);
        }
    }

    function testHiddenZeroCapacityRejected() public {
        try new RingBuffer(0) {
            assertTrue(false, "zero capacity accepted");
        } catch (bytes memory data) {
            assertEq(keccak256(data), keccak256(abi.encodeWithSelector(RingBuffer.ZeroCapacity.selector)));
        }
    }

    function testHiddenEmptyBuffer() public {
        RingBuffer buffer = new RingBuffer(4);
        assertEq(buffer.toArray().length, 0);

        vm.expectRevert(RingBuffer.Empty.selector);
        buffer.latest();
        vm.expectRevert(RingBuffer.Empty.selector);
        buffer.oldest();
        vm.expectRevert(abi.encodeWithSelector(RingBuffer.IndexOutOfBounds.selector, uint256(0), uint256(0)));
        buffer.at(0);
    }

    function testHiddenExactlyFull() public {
        RingBuffer buffer = new RingBuffer(4);
        uint256[] memory expected = new uint256[](4);
        for (uint256 i = 0; i < 4; i++) {
            buffer.push(100 + i);
            expected[i] = 100 + i;
        }
        _assertContents(buffer, expected);
        assertEq(buffer.totalPushed(), 4);

        vm.expectRevert(abi.encodeWithSelector(RingBuffer.IndexOutOfBounds.selector, uint256(4), uint256(4)));
        buffer.at(4);
    }

    function testHiddenEveryStepOfAWrap() public {
        RingBuffer buffer = new RingBuffer(3);
        // After pushing values 1..n the buffer must hold the last min(n, 3) of them.
        for (uint256 n = 1; n <= 11; n++) {
            buffer.push(n);
            uint256 len = n < 3 ? n : 3;
            uint256[] memory expected = new uint256[](len);
            for (uint256 i = 0; i < len; i++) {
                expected[i] = n - len + 1 + i;
            }
            _assertContents(buffer, expected);
            assertEq(buffer.totalPushed(), n);
        }
    }

    function testHiddenCapacityOne() public {
        RingBuffer buffer = new RingBuffer(1);
        buffer.push(7);
        assertEq(buffer.latest(), 7);
        assertEq(buffer.oldest(), 7);
        buffer.push(8);
        buffer.push(9);
        assertEq(buffer.length(), 1);
        assertEq(buffer.at(0), 9);
        assertEq(buffer.toArray()[0], 9);
        assertEq(buffer.totalPushed(), 3);

        vm.expectRevert(abi.encodeWithSelector(RingBuffer.IndexOutOfBounds.selector, uint256(1), uint256(1)));
        buffer.at(1);
    }

    function testHiddenZeroValuesAreStored() public {
        RingBuffer buffer = new RingBuffer(2);
        buffer.push(5);
        buffer.push(0);
        assertEq(buffer.length(), 2);
        assertEq(buffer.latest(), 0);
        buffer.push(0);
        assertEq(buffer.oldest(), 0);
        assertEq(buffer.latest(), 0);
        buffer.push(6);
        assertEq(buffer.oldest(), 0);
        assertEq(buffer.latest(), 6);
    }

    function testHiddenLargeCapacityPartiallyFilled() public {
        RingBuffer buffer = new RingBuffer(1000);
        buffer.push(11);
        buffer.push(22);
        buffer.push(33);
        uint256[] memory expected = new uint256[](3);
        expected[0] = 11;
        expected[1] = 22;
        expected[2] = 33;
        _assertContents(buffer, expected);

        vm.expectRevert(abi.encodeWithSelector(RingBuffer.IndexOutOfBounds.selector, uint256(3), uint256(3)));
        buffer.at(3);
        vm.expectRevert(abi.encodeWithSelector(RingBuffer.IndexOutOfBounds.selector, uint256(999), uint256(3)));
        buffer.at(999);
    }

    function testHiddenBuffersAreIndependent() public {
        RingBuffer a = new RingBuffer(2);
        RingBuffer b = new RingBuffer(5);
        for (uint256 i = 1; i <= 6; i++) {
            a.push(i);
            b.push(i * 10);
        }
        assertEq(a.oldest(), 5);
        assertEq(a.latest(), 6);
        assertEq(b.oldest(), 20);
        assertEq(b.latest(), 60);
        assertEq(b.at(2), 40);
    }
}
