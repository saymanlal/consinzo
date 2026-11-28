// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AsmBytes.sol";

contract AsmBytesHiddenHarness {
    function _fill(uint256 n) private pure returns (bytes memory filler) {
        filler = new bytes(n);
        for (uint256 i = 0; i < n; i++) filler[i] = 0xff;
    }

    function _fmp() private pure returns (uint256 p) {
        assembly {
            p := mload(0x40)
        }
    }

    function _zeroSlot() private pure returns (uint256 z) {
        assembly {
            z := mload(0x60)
        }
    }

    /// Dirties free memory so that implementations relying on zeroed memory are caught.
    function _dirtyFreeMemory(uint256 words) private pure {
        assembly {
            let p := mload(0x40)
            for { let i := 0 } lt(i, words) { i := add(i, 1) } { mstore(add(p, mul(i, 0x20)), not(0)) }
        }
    }

    /// op: 0 = copy(a), 1 = slice(a, x, y), 2 = concat(a, b)
    function run(uint256 op, bytes memory a, bytes memory b, uint256 x, uint256 y)
        external
        pure
        returns (bytes memory out, bool ok)
    {
        bytes32 hashA = keccak256(a);
        bytes32 hashB = keccak256(b);
        _dirtyFreeMemory(8 + (a.length + b.length) / 32);

        if (op == 0) out = AsmBytes.copy(a);
        else if (op == 1) out = AsmBytes.slice(a, x, y);
        else out = AsmBytes.concat(a, b);

        uint256 outPtr;
        assembly {
            outPtr := out
        }
        // The free memory pointer must be behind the data of `out`.
        ok = _fmp() >= outPtr + 32 + out.length;
        bytes32 hashOut = keccak256(out);

        // Later allocations must not disturb the result, inputs must be unchanged.
        _fill(160);
        ok = ok && keccak256(out) == hashOut && keccak256(a) == hashA && keccak256(b) == hashB;
        ok = ok && _zeroSlot() == 0;

        // The result must not alias an input: overwrite the inputs and compare again.
        for (uint256 i = 0; i < a.length; i++) a[i] = ~a[i];
        for (uint256 i = 0; i < b.length; i++) b[i] = ~b[i];
        ok = ok && keccak256(out) == hashOut;
    }

    function hashPairDirty(bytes32 a, bytes32 b) external pure returns (bytes32 digest, bool clean) {
        _dirtyFreeMemory(4);
        uint256 before = _fmp();
        digest = AsmBytes.hashPair(a, b);
        clean = before == _fmp() && _zeroSlot() == 0;
        // A fresh array allocated afterwards must have its proper length word.
        bytes memory later = new bytes(7);
        clean = clean && later.length == 7;
    }

    function hashTripleDirty(bytes32 a, bytes32 b, bytes32 c) external pure returns (bytes32 digest, bool clean) {
        _dirtyFreeMemory(4);
        uint256 before = _fmp();
        digest = AsmBytes.hashTriple(a, b, c);
        clean = before == _fmp() && _zeroSlot() == 0;
        bytes memory later = new bytes(7);
        clean = clean && later.length == 7;
    }

    function hashPackedRaw(uint256 dirtyAccount, uint256 dirtyAmount, bytes32 salt)
        external
        pure
        returns (bytes32 digest, bool clean)
    {
        // Values with dirty upper bits, as they can occur after assembly in a caller.
        address account;
        uint96 amount;
        assembly {
            account := dirtyAccount
            amount := dirtyAmount
        }
        uint256 before = _fmp();
        digest = AsmBytes.hashPacked(account, amount, salt);
        clean = before == _fmp() && _zeroSlot() == 0;
    }

    function hashConcatDirty(bytes memory a, bytes memory b) external pure returns (bytes32 digest, bool clean) {
        bytes32 hashA = keccak256(a);
        bytes32 hashB = keccak256(b);
        _dirtyFreeMemory(8 + (a.length + b.length) / 32);
        uint256 before = _fmp();
        digest = AsmBytes.hashConcat(a, b);
        clean = before == _fmp() && _zeroSlot() == 0 && keccak256(a) == hashA && keccak256(b) == hashB;
    }

    function copyGas(bytes memory data) external view returns (uint256 used) {
        uint256 before = gasleft();
        AsmBytes.copy(data);
        used = before - gasleft();
    }

    function hashConcatGas(bytes memory a, bytes memory b) external view returns (uint256 used) {
        uint256 before = gasleft();
        AsmBytes.hashConcat(a, b);
        used = before - gasleft();
    }
}

contract AsmBytesHiddenTest is Test {
    AsmBytesHiddenHarness public h;

    function setUp() public {
        h = new AsmBytesHiddenHarness();
    }

    function _bytes(uint256 n, uint256 seed) internal pure returns (bytes memory out) {
        out = new bytes(n);
        for (uint256 i = 0; i < n; i++) out[i] = bytes1(uint8(uint256(keccak256(abi.encodePacked(seed, i)))));
    }

    function _lengths() internal pure returns (uint256[8] memory) {
        return [uint256(0), 1, 31, 32, 33, 64, 65, 200];
    }

    function testHiddenCopyAllLengths() public view {
        uint256[8] memory lens = _lengths();
        for (uint256 i = 0; i < lens.length; i++) {
            bytes memory src = _bytes(lens[i], i);
            (bytes memory out, bool ok) = h.run(0, src, "", 0, 0);
            assertTrue(ok);
            assertEq(out.length, lens[i]);
            assertEq(keccak256(out), keccak256(src));
        }
    }

    function testHiddenConcatAllLengthCombinations() public view {
        uint256[8] memory lens = _lengths();
        for (uint256 i = 0; i < lens.length; i++) {
            for (uint256 j = 0; j < lens.length; j += 2) {
                bytes memory a = _bytes(lens[i], 100 + i);
                bytes memory b = _bytes(lens[j], 200 + j);
                (bytes memory out, bool ok) = h.run(2, a, b, 0, 0);
                assertTrue(ok);
                assertEq(keccak256(out), keccak256(abi.encodePacked(a, b)));
            }
        }
    }

    function _expectSlice(bytes memory data, uint256 start, uint256 length) internal view {
        bytes memory expected = new bytes(length);
        for (uint256 i = 0; i < length; i++) expected[i] = data[start + i];
        (bytes memory out, bool ok) = h.run(1, data, "", start, length);
        assertTrue(ok);
        assertEq(out.length, length);
        assertEq(keccak256(out), keccak256(expected));
    }

    function testHiddenSliceRanges() public view {
        bytes memory data = _bytes(130, 9);
        _expectSlice(data, 0, 130);
        _expectSlice(data, 0, 0);
        _expectSlice(data, 130, 0);
        _expectSlice(data, 129, 1);
        _expectSlice(data, 1, 31);
        _expectSlice(data, 31, 33);
        _expectSlice(data, 64, 64);
        _expectSlice(data, 7, 100);
    }

    function testHiddenSliceBoundsAndOverflow() public {
        bytes memory data = _bytes(64, 10);
        vm.expectRevert(AsmBytes.OutOfBounds.selector);
        h.run(1, data, "", 65, 0);
        vm.expectRevert(AsmBytes.OutOfBounds.selector);
        h.run(1, data, "", 0, 65);
        vm.expectRevert(AsmBytes.OutOfBounds.selector);
        h.run(1, data, "", 64, 1);
        // start + length wraps around to a small number.
        vm.expectRevert(AsmBytes.OutOfBounds.selector);
        h.run(1, data, "", type(uint256).max, 2);
        vm.expectRevert(AsmBytes.OutOfBounds.selector);
        h.run(1, data, "", 2, type(uint256).max);
        vm.expectRevert(AsmBytes.OutOfBounds.selector);
        h.run(1, "", "", 1, 0);
    }

    function testHiddenHashesDoNotAllocate() public view {
        bytes32 a = keccak256("x");
        bytes32 b = keccak256("y");
        bytes32 c = keccak256("z");
        (bytes32 d, bool clean) = h.hashPairDirty(a, b);
        assertEq(d, keccak256(abi.encodePacked(a, b)));
        assertTrue(clean);
        (d, clean) = h.hashTripleDirty(a, b, c);
        assertEq(d, keccak256(abi.encodePacked(a, b, c)));
        assertTrue(clean);
        (d, clean) = h.hashTripleDirty(bytes32(0), bytes32(0), bytes32(0));
        assertEq(d, keccak256(new bytes(96)));
        assertTrue(clean);
    }

    function testHiddenHashPackedCleansDirtyBits() public view {
        address account = 0x00112233445566778899AABbCCdDeeFf00112233;
        uint96 amount = type(uint96).max - 5;
        bytes32 salt = keccak256("s");
        bytes32 expected = keccak256(abi.encodePacked(account, amount, salt));

        (bytes32 d, bool clean) = h.hashPackedRaw(uint256(uint160(account)), uint256(amount), salt);
        assertEq(d, expected);
        assertTrue(clean);

        // Same values with garbage in the unused upper bits.
        uint256 dirtyAccount = uint256(uint160(account)) | (uint256(0xdeadbeef) << 200);
        uint256 dirtyAmount = uint256(amount) | (uint256(0xff) << 96) | (uint256(1) << 255);
        (d, clean) = h.hashPackedRaw(dirtyAccount, dirtyAmount, salt);
        assertEq(d, expected);
        assertTrue(clean);

        (d,) = h.hashPackedRaw(0, 0, bytes32(0));
        assertEq(d, keccak256(abi.encodePacked(address(0), uint96(0), bytes32(0))));
    }

    function testHiddenHashConcatAllLengths() public view {
        uint256[8] memory lens = _lengths();
        for (uint256 i = 0; i < lens.length; i++) {
            for (uint256 j = 1; j < lens.length; j += 2) {
                bytes memory a = _bytes(lens[i], 300 + i);
                bytes memory b = _bytes(lens[j], 400 + j);
                (bytes32 d, bool clean) = h.hashConcatDirty(a, b);
                assertEq(d, keccak256(abi.encodePacked(a, b)));
                assertTrue(clean);
            }
        }
        (bytes32 empty, bool cleanEmpty) = h.hashConcatDirty("", "");
        assertEq(empty, keccak256(""));
        assertTrue(cleanEmpty);
    }

    function testHiddenGasBounds() public view {
        bytes memory big = new bytes(4096);
        for (uint256 i = 0; i < 4096; i += 32) big[i] = bytes1(uint8(i / 32));
        assertLt(h.copyGas(big), 20000);

        bytes memory half = new bytes(2048);
        half[5] = 0x01;
        assertLt(h.hashConcatGas(half, half), 25000);
    }
}
