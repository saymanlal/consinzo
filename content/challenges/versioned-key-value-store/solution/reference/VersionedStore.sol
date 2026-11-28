// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract VersionedStore {
    error VersionMismatch(bytes32 key, uint64 expected, uint64 actual);
    error KeyNotFound(bytes32 key);
    error UnknownVersion(bytes32 key, uint64 version);

    event ValueSet(bytes32 indexed key, uint64 indexed version, bytes value);
    event ValueRemoved(bytes32 indexed key, uint64 indexed version);

    struct Entry {
        uint64 version; // 0 means "never written"
        bool live; // false after a removal; an empty value is still live
    }

    mapping(bytes32 => Entry) private _entries;
    // key => version => value written at that version (empty for removals)
    mapping(bytes32 => mapping(uint64 => bytes)) private _history;

    function set(bytes32 key, bytes calldata value, uint64 expectedVersion) external returns (uint64 newVersion) {
        Entry storage entry = _entries[key];
        if (entry.version != expectedVersion) revert VersionMismatch(key, expectedVersion, entry.version);

        newVersion = expectedVersion + 1;
        entry.version = newVersion;
        entry.live = true;
        _history[key][newVersion] = value;

        emit ValueSet(key, newVersion, value);
    }

    function remove(bytes32 key, uint64 expectedVersion) external returns (uint64 newVersion) {
        Entry storage entry = _entries[key];
        if (entry.version != expectedVersion) revert VersionMismatch(key, expectedVersion, entry.version);
        if (!entry.live) revert KeyNotFound(key);

        // The version keeps counting. Resetting it would let a writer that still expects an
        // old version succeed against a key that has since been written and removed.
        newVersion = expectedVersion + 1;
        entry.version = newVersion;
        entry.live = false;

        emit ValueRemoved(key, newVersion);
    }

    function get(bytes32 key) external view returns (bytes memory value, uint64 version) {
        Entry storage entry = _entries[key];
        version = entry.version;
        if (entry.live) value = _history[key][version];
    }

    function versionOf(bytes32 key) external view returns (uint64) {
        return _entries[key].version;
    }

    function exists(bytes32 key) external view returns (bool) {
        return _entries[key].live;
    }

    function valueAt(bytes32 key, uint64 version) external view returns (bytes memory) {
        if (version == 0 || version > _entries[key].version) revert UnknownVersion(key, version);
        return _history[key][version];
    }
}
