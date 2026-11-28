// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AsmBytes.sol";

/// Exposes the internal library functions and observes memory around them.
contract AsmBytesHarness {
    function _fill(uint256 n) private pure returns (bytes memory filler) {
        filler = new bytes(n);
        for (uint256 i = 0; i < n; i++) filler[i] = 0xff;
    }

    function copy(bytes memory src) external pure returns (bytes memory) {
        bytes memory out = AsmBytes.copy(src);
        _fill(96); // a later allocation must not overlap `out`
        return out;
    }

    function slice(bytes memory data, uint256 start, uint256 length) external pure returns (bytes memory) {
        bytes memory out = AsmBytes.slice(data, start, length);
        _fill(96);
        return out;
    }

    function concat(bytes memory a, bytes memory b) external pure returns (bytes memory) {
        bytes memory out = AsmBytes.concat(a, b);
        _fill(96);
        return out;
    }

    function _memoryState() private pure returns (uint256 freePointer, uint256 zeroSlot) {
        assembly {
            freePointer := mload(0x40)
            zeroSlot := mload(0x60)
        }
    }

    /// which: 0 = hashPair, 1 = hashTriple, 2 = hashPacked
    function hashWords(uint256 which, bytes32 a, bytes32 b, bytes32 c)
        external
        pure
        returns (bytes32 digest, bool memoryUntouched)
    {
        (uint256 fmpBefore,) = _memoryState();
        if (which == 0) digest = AsmBytes.hashPair(a, b);
        else if (which == 1) digest = AsmBytes.hashTriple(a, b, c);
        else digest = AsmBytes.hashPacked(address(uint160(uint256(a))), uint96(uint256(b)), c);
        (uint256 fmpAfter, uint256 zeroSlot) = _memoryState();
        memoryUntouched = fmpBefore == fmpAfter && zeroSlot == 0;
    }

    function hashConcat(bytes memory a, bytes memory b) external pure returns (bytes32 digest, bool memoryUntouched) {
        (uint256 fmpBefore,) = _memoryState();
        digest = AsmBytes.hashConcat(a, b);
        (uint256 fmpAfter, uint256 zeroSlot) = _memoryState();
        memoryUntouched = fmpBefore == fmpAfter && zeroSlot == 0;
    }
}

contract AsmBytesTest is Test {
    AsmBytesHarness public h;

    function setUp() public {
        h = new AsmBytesHarness();
    }

    function _bytes(uint256 n, uint256 seed) internal pure returns (bytes memory out) {
        out = new bytes(n);
        for (uint256 i = 0; i < n; i++) out[i] = bytes1(uint8(uint256(keccak256(abi.encodePacked(seed, i)))));
    }

    function testCopyMatchesSource() public view {
        bytes memory src = _bytes(100, 1);
        bytes memory out = h.copy(src);
        assertEq(out.length, 100);
        assertEq(keccak256(out), keccak256(src));
    }

    function testSliceMatchesReference() public view {
        bytes memory data = _bytes(100, 2);
        bytes memory out = h.slice(data, 5, 70);
        assertEq(out.length, 70);
        for (uint256 i = 0; i < 70; i++) assertTrue(out[i] == data[5 + i]);
    }

    function testSliceOutOfBoundsReverts() public {
        bytes memory data = _bytes(10, 3);
        vm.expectRevert(AsmBytes.OutOfBounds.selector);
        h.slice(data, 5, 6);
    }

    function testConcatMatchesEncodePacked() public view {
        bytes memory a = _bytes(33, 4);
        bytes memory b = _bytes(70, 5);
        assertEq(keccak256(h.concat(a, b)), keccak256(abi.encodePacked(a, b)));
    }

    function testHashPairAndTriple() public view {
        bytes32 a = keccak256("a");
        bytes32 b = keccak256("b");
        bytes32 c = keccak256("c");
        (bytes32 pair, bool cleanPair) = h.hashWords(0, a, b, c);
        assertEq(pair, keccak256(abi.encodePacked(a, b)));
        assertTrue(cleanPair);
        (bytes32 triple, bool cleanTriple) = h.hashWords(1, a, b, c);
        assertEq(triple, keccak256(abi.encodePacked(a, b, c)));
        assertTrue(cleanTriple);
    }

    function testHashPacked() public view {
        address account = address(0xA11CE);
        uint96 amount = 123456789;
        bytes32 salt = keccak256("salt");
        (bytes32 digest, bool clean) =
            h.hashWords(2, bytes32(uint256(uint160(account))), bytes32(uint256(amount)), salt);
        assertEq(digest, keccak256(abi.encodePacked(account, amount, salt)));
        assertTrue(clean);
    }

    function testHashConcat() public view {
        bytes memory a = _bytes(45, 6);
        bytes memory b = _bytes(90, 7);
        (bytes32 digest, bool clean) = h.hashConcat(a, b);
        assertEq(digest, keccak256(abi.encodePacked(a, b)));
        assertTrue(clean);
    }
}
