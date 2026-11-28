// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BloomFilter.sol";

contract BloomFilterTest is Test {
    BloomFilter public filter;
    uint256 internal constant M = 1000;
    uint8 internal constant K = 3;

    function setUp() public {
        filter = new BloomFilter(M, K);
    }

    function _index(bytes32 item, uint8 i, uint256 m) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(item, i))) % m;
    }

    function _item(uint256 i) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("item", i));
    }

    function testParameters() public view {
        assertEq(filter.bitCount(), M);
        assertEq(uint256(filter.hashCount()), 3);
        assertEq(filter.setBits(), 0);
    }

    function testBitIndexFollowsFormula() public view {
        bytes32 item = _item(1);
        for (uint8 i = 0; i < K; i++) {
            assertEq(filter.bitIndex(item, i), _index(item, i, M));
            assertLt(filter.bitIndex(item, i), M);
        }
    }

    function testAddSetsExactlyTheItemBits() public {
        bytes32 item = _item(2);
        assertFalse(filter.mightContain(item));
        assertTrue(filter.add(item));
        assertTrue(filter.mightContain(item));
        for (uint8 i = 0; i < K; i++) {
            assertTrue(filter.bitAt(_index(item, i, M)));
        }
        assertLe(filter.setBits(), 3);
        assertGe(filter.setBits(), 1);
    }

    function testAddingTwiceChangesNothing() public {
        bytes32 item = _item(3);
        assertTrue(filter.add(item));
        uint256 bits = filter.setBits();
        assertFalse(filter.add(item));
        assertEq(filter.setBits(), bits);
    }

    function testNoFalseNegatives() public {
        for (uint256 i = 0; i < 20; i++) filter.add(_item(i));
        for (uint256 i = 0; i < 20; i++) assertTrue(filter.mightContain(_item(i)));
    }
}
