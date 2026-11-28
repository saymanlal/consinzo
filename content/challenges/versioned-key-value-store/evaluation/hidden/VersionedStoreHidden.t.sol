// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/VersionedStore.sol";

contract VersionedStoreHiddenTest is Test {
    VersionedStore public store;
    bytes32 internal constant A = keccak256("a");
    bytes32 internal constant B = keccak256("b");

    function setUp() public {
        store = new VersionedStore();
    }

    function testHiddenVersionNeverResetsAfterRemove() public {
        store.set(A, hex"01", 0);
        store.remove(A, 1);

        // A stale writer that thinks the key was never written must be rejected.
        vm.expectRevert(abi.encodeWithSelector(VersionedStore.VersionMismatch.selector, A, uint64(0), uint64(2)));
        store.set(A, hex"ff", 0);

        uint64 v = store.set(A, hex"02", 2);
        assertEq(uint256(v), 3);
        assertTrue(store.exists(A));
        (bytes memory value,) = store.get(A);
        assertEq(keccak256(value), keccak256(hex"02"));
    }

    function testHiddenRemoveChecksVersionBeforeExistence() public {
        // Never written: version 0, not live.
        vm.expectRevert(abi.encodeWithSelector(VersionedStore.VersionMismatch.selector, A, uint64(5), uint64(0)));
        store.remove(A, 5);

        vm.expectRevert(abi.encodeWithSelector(VersionedStore.KeyNotFound.selector, A));
        store.remove(A, 0);

        store.set(A, hex"01", 0);
        store.remove(A, 1);
        vm.expectRevert(abi.encodeWithSelector(VersionedStore.KeyNotFound.selector, A));
        store.remove(A, 2);
        assertEq(uint256(store.versionOf(A)), 2);
    }

    function testHiddenEmptyValueIsStillLive() public {
        uint64 v = store.set(A, "", 0);
        assertEq(uint256(v), 1);
        assertTrue(store.exists(A));
        (bytes memory value, uint64 version) = store.get(A);
        assertEq(value.length, 0);
        assertEq(uint256(version), 1);

        // It can be removed, which proves it was treated as existing.
        assertEq(uint256(store.remove(A, 1)), 2);
        assertFalse(store.exists(A));
    }

    function testHiddenKeysAreIndependent() public {
        store.set(A, hex"0a", 0);
        store.set(A, hex"0b", 1);
        store.set(B, hex"0c", 0);

        assertEq(uint256(store.versionOf(A)), 2);
        assertEq(uint256(store.versionOf(B)), 1);
        assertEq(keccak256(store.valueAt(B, 1)), keccak256(hex"0c"));

        vm.expectRevert(abi.encodeWithSelector(VersionedStore.UnknownVersion.selector, B, uint64(2)));
        store.valueAt(B, 2);
    }

    function testHiddenHistoryAcrossRemovalAndBounds() public {
        bytes memory long = new bytes(100);
        for (uint256 i = 0; i < 100; i++) long[i] = bytes1(uint8(i));

        store.set(A, long, 0);
        store.remove(A, 1);
        store.set(A, hex"beef", 2);

        assertEq(keccak256(store.valueAt(A, 1)), keccak256(long));
        assertEq(store.valueAt(A, 2).length, 0);
        assertEq(keccak256(store.valueAt(A, 3)), keccak256(hex"beef"));

        vm.expectRevert(abi.encodeWithSelector(VersionedStore.UnknownVersion.selector, A, uint64(0)));
        store.valueAt(A, 0);
        vm.expectRevert(abi.encodeWithSelector(VersionedStore.UnknownVersion.selector, A, uint64(4)));
        store.valueAt(A, 4);
    }

    function testHiddenFailedWriteLeavesStateUntouched() public {
        store.set(A, hex"01", 0);
        vm.expectRevert(VersionedStore.VersionMismatch.selector);
        store.set(A, hex"02", 2);
        vm.expectRevert(VersionedStore.VersionMismatch.selector);
        store.remove(A, 0);

        (bytes memory value, uint64 version) = store.get(A);
        assertEq(keccak256(value), keccak256(hex"01"));
        assertEq(uint256(version), 1);
        assertTrue(store.exists(A));
    }

    function testHiddenLongSequenceOfWrites() public {
        for (uint64 i = 0; i < 20; i++) {
            uint64 v = store.set(A, abi.encodePacked(i), i);
            assertEq(uint256(v), uint256(i) + 1);
        }
        assertEq(uint256(store.versionOf(A)), 20);
        assertEq(keccak256(store.valueAt(A, 7)), keccak256(abi.encodePacked(uint64(6))));
    }
}
