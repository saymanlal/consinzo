// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StringUtils.sol";

contract StringUtilsHiddenTest is Test {
    StringUtils public utils;

    function setUp() public {
        utils = new StringUtils();
    }

    function testHiddenByteLengthCountsBytesNotCharacters() public view {
        // U+00E9 is two bytes in UTF-8, U+20AC three, U+1F600 four.
        assertEq(utils.byteLength(unicode"é"), 2);
        assertEq(utils.byteLength(unicode"€"), 3);
        assertEq(utils.byteLength(unicode"😀"), 4);
        assertEq(utils.byteLength(unicode"café"), 5);
        assertEq(utils.byteLength("a string that is definitely longer than thirty-two bytes"), 56);
    }

    function testHiddenEqualEdgeCases() public view {
        assertTrue(utils.equal("", ""));
        assertFalse(utils.equal("", " "));
        assertFalse(utils.equal("abc", "abcd"));
        assertFalse(utils.equal("abcd", "abc"));
        assertFalse(utils.equal("abc", "abd"));
        assertTrue(utils.equal(unicode"naïve", unicode"naïve"));
        assertFalse(utils.equal("ab", "ba"));
    }

    function testHiddenBytesEqual() public view {
        assertTrue(utils.bytesEqual(hex"", hex""));
        assertTrue(utils.bytesEqual(hex"deadbeef", hex"deadbeef"));
        assertFalse(utils.bytesEqual(hex"deadbeef", hex"deadbe"));
        assertFalse(utils.bytesEqual(hex"00", hex""));
        assertFalse(utils.bytesEqual(hex"00", hex"0000"));
        assertFalse(utils.bytesEqual(hex"01", hex"02"));
        assertTrue(utils.bytesEqual(bytes("abc"), hex"616263"));
    }

    function testHiddenConcatEdgeCases() public view {
        assertEq(utils.concat("", ""), "");
        assertEq(utils.concat("left", ""), "left");
        assertEq(utils.concat("", "right"), "right");
        assertEq(utils.concat("ab", "ba"), "abba");

        string memory joined = utils.concat("thirty-two bytes is one full word", " and this part spills over");
        assertEq(joined, "thirty-two bytes is one full word and this part spills over");
        assertEq(bytes(joined).length, 59);

        // Order matters.
        assertFalse(keccak256(bytes(utils.concat("a", "b"))) == keccak256(bytes(utils.concat("b", "a"))));
    }

    function testHiddenConcatBytes() public view {
        bytes memory joined = utils.concatBytes(hex"0102", hex"0304ff");
        assertEq(joined.length, 5);
        assertEq(keccak256(joined), keccak256(hex"01020304ff"));
        assertEq(utils.concatBytes(hex"", hex"").length, 0);
        assertEq(keccak256(utils.concatBytes(hex"00", hex"")), keccak256(hex"00"));
        assertEq(keccak256(utils.concatBytes(hex"", hex"00")), keccak256(hex"00"));
    }

    function testHiddenStartsWithEdgeCases() public view {
        assertTrue(utils.startsWith("abc", ""));
        assertTrue(utils.startsWith("", ""));
        assertFalse(utils.startsWith("", "a"));
        assertTrue(utils.startsWith("abc", "abc"));
        assertFalse(utils.startsWith("abc", "abcd"));
        assertFalse(utils.startsWith("abc", "abd"));
        assertFalse(utils.startsWith("abc", "bc"));
        assertFalse(utils.startsWith("abc", "Abc"));
        assertTrue(utils.startsWith("0xdeadbeef", "0x"));
        assertTrue(
            utils.startsWith(
                "a long string that crosses the thirty-two byte boundary somewhere here",
                "a long string that crosses the thirty-two byte boundary"
            )
        );
        assertFalse(
            utils.startsWith(
                "a long string that crosses the thirty-two byte boundary somewhere here",
                "a long string that crosses the thirty-two byte boundarY"
            )
        );
    }

    function testHiddenRangeIsInclusive() public view {
        assertTrue(utils.isLengthBetween("abc", 3, 3));
        assertTrue(utils.isLengthBetween("abc", 3, 10));
        assertTrue(utils.isLengthBetween("abc", 0, 3));
        assertFalse(utils.isLengthBetween("abc", 4, 10));
        assertFalse(utils.isLengthBetween("abc", 0, 2));
        assertTrue(utils.isLengthBetween("", 0, 0));
        assertFalse(utils.isLengthBetween("", 1, 5));
        assertTrue(utils.isLengthBetween("abc", 0, type(uint256).max));
        // Bytes, not characters.
        assertFalse(utils.isLengthBetween(unicode"€€", 1, 5));
        assertTrue(utils.isLengthBetween(unicode"€€", 6, 6));
    }

    function testHiddenInvertedRangeNeverMatchesOrPanics() public {
        assertFalse(utils.isLengthBetween("abc", 5, 1));
        assertFalse(utils.isLengthBetween("abc", 4, 3));
        vm.expectRevert(
            abi.encodeWithSelector(StringUtils.LengthOutOfRange.selector, uint256(3), uint256(5), uint256(1))
        );
        utils.validateLength("abc", 5, 1);
    }

    function testHiddenValidateLength() public {
        assertEq(utils.validateLength("", 0, 0), 0);
        assertEq(utils.validateLength("abc", 3, 3), 3);
        assertEq(utils.validateLength(unicode"é", 2, 2), 2);

        vm.expectRevert(
            abi.encodeWithSelector(StringUtils.LengthOutOfRange.selector, uint256(0), uint256(1), uint256(32))
        );
        utils.validateLength("", 1, 32);

        vm.expectRevert(
            abi.encodeWithSelector(StringUtils.LengthOutOfRange.selector, uint256(2), uint256(3), uint256(8))
        );
        utils.validateLength("ab", 3, 8);

        vm.expectRevert(
            abi.encodeWithSelector(StringUtils.LengthOutOfRange.selector, uint256(9), uint256(3), uint256(8))
        );
        utils.validateLength("abcdefghi", 3, 8);
    }
}
