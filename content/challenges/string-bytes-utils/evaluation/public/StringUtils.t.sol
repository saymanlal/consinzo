// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StringUtils.sol";

contract StringUtilsTest is Test {
    StringUtils public utils;

    function setUp() public {
        utils = new StringUtils();
    }

    function testByteLength() public view {
        assertEq(utils.byteLength(""), 0);
        assertEq(utils.byteLength("hello"), 5);
    }

    function testEqual() public view {
        assertTrue(utils.equal("solidity", "solidity"));
        assertFalse(utils.equal("solidity", "Solidity"));
    }

    function testConcat() public view {
        assertEq(utils.concat("foo", "bar"), "foobar");
    }

    function testStartsWith() public view {
        assertTrue(utils.startsWith("consinzo", "con"));
        assertFalse(utils.startsWith("consinzo", "zo"));
    }

    function testLengthValidation() public {
        assertTrue(utils.isLengthBetween("abc", 1, 5));
        assertFalse(utils.isLengthBetween("abcdef", 1, 5));
        assertEq(utils.validateLength("abc", 1, 5), 3);

        vm.expectRevert(
            abi.encodeWithSelector(StringUtils.LengthOutOfRange.selector, uint256(6), uint256(1), uint256(5))
        );
        utils.validateLength("abcdef", 1, 5);
    }
}
