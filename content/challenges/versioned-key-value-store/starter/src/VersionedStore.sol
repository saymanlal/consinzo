// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract VersionedStore {
    error VersionMismatch(bytes32 key, uint64 expected, uint64 actual);
    error KeyNotFound(bytes32 key);
    error UnknownVersion(bytes32 key, uint64 version);

    event ValueSet(bytes32 indexed key, uint64 indexed version, bytes value);
    event ValueRemoved(bytes32 indexed key, uint64 indexed version);

    // TODO: declare the storage you need (current version, liveness, value per version).

    function set(bytes32 key, bytes calldata value, uint64 expectedVersion) external returns (uint64 newVersion) {
        // TODO: check expectedVersion, bump the version, store the value, emit ValueSet.
        revert("NOT_IMPLEMENTED");
    }

    function remove(bytes32 key, uint64 expectedVersion) external returns (uint64 newVersion) {
        // TODO: check expectedVersion, then existence, bump the version, emit ValueRemoved.
        revert("NOT_IMPLEMENTED");
    }

    function get(bytes32 key) external view returns (bytes memory value, uint64 version) {
        // TODO
        revert("NOT_IMPLEMENTED");
    }

    function versionOf(bytes32 key) external view returns (uint64) {
        // TODO
        return 0;
    }

    function exists(bytes32 key) external view returns (bool) {
        // TODO
        return false;
    }

    function valueAt(bytes32 key, uint64 version) external view returns (bytes memory) {
        // TODO: revert with UnknownVersion for version 0 or a version above the current one.
        revert("NOT_IMPLEMENTED");
    }
}
