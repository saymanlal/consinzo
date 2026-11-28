// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BloomFilter.sol";

contract BloomFilterHiddenTest is Test {
    function _index(bytes32 item, uint8 i, uint256 m) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(item, i))) % m;
    }

    function _item(uint256 i) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("hidden-item", i));
    }

    function _popcount(uint256 x) internal pure returns (uint256 c) {
        while (x != 0) {
            x &= x - 1;
            c++;
        }
    }

    function testHiddenWordLayoutMatchesModel() public {
        uint256 m = 700; // three words, the last one partially used
        uint8 k = 4;
        BloomFilter filter = new BloomFilter(m, k);
        uint256[3] memory model;
        for (uint256 n = 0; n < 25; n++) {
            bytes32 item = _item(n);
            bool expectChanged = false;
            for (uint8 i = 0; i < k; i++) {
                uint256 idx = _index(item, i, m);
                uint256 mask = uint256(1) << (idx % 256);
                if (model[idx / 256] & mask == 0) {
                    model[idx / 256] |= mask;
                    expectChanged = true;
                }
            }
            assertEq(filter.add(item), expectChanged);
        }
        uint256 total = 0;
        for (uint256 w = 0; w < 3; w++) {
            assertEq(filter.word(w), model[w]);
            total += _popcount(model[w]);
        }
        assertEq(filter.word(3), 0);
        assertEq(filter.setBits(), total);
    }

    function testHiddenSetBitsCountsCollidingPositionsOnce() public {
        // With a single bit every hash function maps to bit 0.
        BloomFilter one = new BloomFilter(1, 16);
        assertTrue(one.add(_item(1)));
        assertEq(one.setBits(), 1);
        assertFalse(one.add(_item(2)));
        assertEq(one.setBits(), 1);
        assertEq(one.word(0), 1);

        // With two bits and eight hash functions the count can never exceed two.
        BloomFilter two = new BloomFilter(2, 8);
        for (uint256 i = 0; i < 6; i++) two.add(_item(i));
        assertEq(two.setBits(), _popcount(two.word(0)));
        assertLe(two.setBits(), 2);
    }

    function testHiddenFalsePositiveWhenSaturated() public {
        BloomFilter filter = new BloomFilter(8, 2);
        uint256 i = 0;
        while (filter.setBits() < 8) {
            filter.add(_item(i));
            i++;
            assertLt(i, 200);
        }
        assertEq(filter.word(0), 0xff);
        // Never added, yet every bit it maps to is set.
        bytes32 stranger = keccak256("never added");
        assertTrue(filter.mightContain(stranger));
        assertFalse(filter.add(stranger));
        assertEq(filter.setBits(), 8);
    }

    function testHiddenDefinitelyAbsentWhenOneBitIsClear() public {
        uint256 m = 4096;
        BloomFilter filter = new BloomFilter(m, 5);
        bytes32 present = _item(100);
        filter.add(present);
        // Find items that share no bit with `present`: they must be reported absent.
        uint256 checked = 0;
        for (uint256 n = 0; n < 30; n++) {
            bytes32 other = _item(n);
            bool allSet = true;
            for (uint8 i = 0; i < 5; i++) {
                if (!filter.bitAt(_index(other, i, m))) allSet = false;
            }
            assertEq(filter.mightContain(other), allSet);
            if (!allSet) checked++;
        }
        assertGt(checked, 20);
        assertTrue(filter.mightContain(present));
    }

    function testHiddenPartialOverlapStillReportsChange() public {
        uint256 m = 16;
        BloomFilter filter = new BloomFilter(m, 3);
        // Add items until one of them overlaps partially with the existing bits.
        bool sawPartial = false;
        for (uint256 n = 0; n < 40 && filter.setBits() < m; n++) {
            bytes32 item = _item(n);
            uint256 alreadySet = 0;
            uint256 fresh = 0;
            uint256 seenMask = 0;
            for (uint8 i = 0; i < 3; i++) {
                uint256 idx = _index(item, i, m);
                if (seenMask & (1 << idx) != 0) continue;
                seenMask |= 1 << idx;
                if (filter.bitAt(idx)) alreadySet++;
                else fresh++;
            }
            uint256 before = filter.setBits();
            bool changed = filter.add(item);
            assertEq(changed, fresh > 0);
            assertEq(filter.setBits(), before + fresh);
            if (alreadySet > 0 && fresh > 0) sawPartial = true;
        }
        assertTrue(sawPartial);
    }

    function testHiddenRevertConditions() public {
        BloomFilter filter = new BloomFilter(300, 2);
        assertFalse(filter.bitAt(299));
        vm.expectRevert(BloomFilter.IndexOutOfRange.selector);
        filter.bitAt(300);
        vm.expectRevert(BloomFilter.InvalidHashIndex.selector);
        filter.bitIndex(_item(1), 2);
        assertLt(filter.bitIndex(_item(1), 1), 300);
    }

    function testHiddenConstructorValidation() public {
        try new BloomFilter(0, 3) {
            assertTrue(false, "m = 0 accepted");
        } catch (bytes memory err) {
            assertEq(bytes4(err), BloomFilter.InvalidParameters.selector);
        }
        try new BloomFilter(64, 0) {
            assertTrue(false, "k = 0 accepted");
        } catch (bytes memory err) {
            assertEq(bytes4(err), BloomFilter.InvalidParameters.selector);
        }
        try new BloomFilter(64, 17) {
            assertTrue(false, "k = 17 accepted");
        } catch (bytes memory err) {
            assertEq(bytes4(err), BloomFilter.InvalidParameters.selector);
        }
        BloomFilter ok = new BloomFilter(64, 16);
        assertEq(uint256(ok.hashCount()), 16);
    }
}
