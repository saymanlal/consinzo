// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/VersionedStore.sol";

contract VersionedStoreTest is Test {
    VersionedStore public store;
    bytes32 internal constant KEY = keccak256("config/fee");
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        store = new VersionedStore();
    }

    function testFirstWriteStartsAtVersionOne() public {
        assertEq(uint256(store.versionOf(KEY)), 0);
        assertFalse(store.exists(KEY));

        uint64 v = store.set(KEY, hex"1234", 0);
        assertEq(uint256(v), 1);

        (bytes memory value, uint64 version) = store.get(KEY);
        assertEq(keccak256(value), keccak256(hex"1234"));
        assertEq(uint256(version), 1);
        assertTrue(store.exists(KEY));
    }

    function testConditionalWriteRequiresCurrentVersion() public {
        store.set(KEY, hex"01", 0);

        vm.prank(alice);
        uint64 v = store.set(KEY, hex"02", 1);
        assertEq(uint256(v), 2);

        // Bob still believes the key is at version 1.
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(VersionedStore.VersionMismatch.selector, KEY, uint64(1), uint64(2)));
        store.set(KEY, hex"03", 1);

        (bytes memory value, uint64 version) = store.get(KEY);
        assertEq(keccak256(value), keccak256(hex"02"));
        assertEq(uint256(version), 2);
    }

    function testRemoveBumpsVersion() public {
        store.set(KEY, hex"aa", 0);
        uint64 v = store.remove(KEY, 1);
        assertEq(uint256(v), 2);
        assertFalse(store.exists(KEY));

        (bytes memory value, uint64 version) = store.get(KEY);
        assertEq(value.length, 0);
        assertEq(uint256(version), 2);
    }

    function testHistoryLookup() public {
        store.set(KEY, hex"aa", 0);
        store.set(KEY, hex"bbbb", 1);
        assertEq(keccak256(store.valueAt(KEY, 1)), keccak256(hex"aa"));
        assertEq(keccak256(store.valueAt(KEY, 2)), keccak256(hex"bbbb"));

        vm.expectRevert(VersionedStore.UnknownVersion.selector);
        store.valueAt(KEY, 3);
    }
}
