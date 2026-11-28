# Versioned Key-Value Store with Conditional Writes

## Problem Statement

Several writers share one on-chain key-value store. To stop them from overwriting each
other's updates without noticing, every key has a version number and every write states the
version the writer last saw. A write that is based on stale data is rejected.

Implement `VersionedStore` in `src/VersionedStore.sol`.

## Required Interface

```solidity
error VersionMismatch(bytes32 key, uint64 expected, uint64 actual);
error KeyNotFound(bytes32 key);
error UnknownVersion(bytes32 key, uint64 version);

event ValueSet(bytes32 indexed key, uint64 indexed version, bytes value);
event ValueRemoved(bytes32 indexed key, uint64 indexed version);

function set(bytes32 key, bytes calldata value, uint64 expectedVersion) external returns (uint64 newVersion);
function remove(bytes32 key, uint64 expectedVersion) external returns (uint64 newVersion);
function get(bytes32 key) external view returns (bytes memory value, uint64 version);
function versionOf(bytes32 key) external view returns (uint64);
function exists(bytes32 key) external view returns (bool);
function valueAt(bytes32 key, uint64 version) external view returns (bytes memory);
```

## Rules

1. A key that was never written has version `0` and does not exist.
2. `set` succeeds only if `expectedVersion` equals the key's current version. Otherwise it
   reverts with `VersionMismatch(key, expectedVersion, currentVersion)`. On success the
   version increases by exactly one, the value is stored, the key exists, `ValueSet` is
   emitted and the new version is returned. An empty `value` is a valid value.
3. `remove` applies the same version check first. If the version matches but the key does
   not exist, it reverts with `KeyNotFound(key)`. On success the version increases by one,
   the key no longer exists, `ValueRemoved` is emitted and the new version is returned.
   The version is never reset: a removed key can be set again with its current version.
4. `get` returns the current value and version. For a key that does not exist it returns
   empty bytes together with the current version (which is non-zero for a removed key).
5. `valueAt(key, version)` returns the value written at that version. It reverts with
   `UnknownVersion(key, version)` when `version` is `0` or greater than the current
   version. For a version created by `remove` it returns empty bytes.
6. Anyone may write. Keys are independent of each other.

## What the Tests Check

- Version counting across sets and removals, and the exact `VersionMismatch` arguments.
- That stale writers are rejected and leave the stored value untouched.
- History lookups, empty values, and the difference between an empty value and a removed key.
