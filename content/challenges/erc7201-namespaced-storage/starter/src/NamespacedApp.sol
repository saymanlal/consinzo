// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract NamespacedApp {
    error AlreadyInitialized();
    error ZeroAddress();
    error NotOwner();
    error NotPendingOwner();
    error LimitReached();

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Incremented(address indexed account, uint256 newTotal);
    event LimitSet(uint256 limit);

    /// @custom:storage-location erc7201:consinzo.storage.Ownable
    struct OwnableStorage {
        address owner;
        address pendingOwner;
    }

    /// @custom:storage-location erc7201:consinzo.storage.Counter
    struct CounterStorage {
        uint256 total;
        uint256 limit;
        mapping(address => uint256) perUser;
    }

    // TODO: define the two namespace locations and functions that return storage pointers
    //       to the structs above. Do not declare ordinary state variables.

    /// @notice ERC-7201 location of the namespace `id`.
    function namespaceSlot(string calldata id) external pure returns (bytes32) {
        // TODO
        revert("NOT_IMPLEMENTED");
    }

    /// @notice Raw storage read. Used by the tests to inspect the layout. Do not change.
    function readSlot(bytes32 slot) external view returns (bytes32 value) {
        assembly {
            value := sload(slot)
        }
    }

    // ---------------------------------------------------------------- ownership module

    function initialize(address initialOwner) external {
        // TODO
        revert("NOT_IMPLEMENTED");
    }

    function owner() external view returns (address) {
        // TODO
        return address(0);
    }

    function pendingOwner() external view returns (address) {
        // TODO
        return address(0);
    }

    function transferOwnership(address newOwner) external {
        // TODO
        revert("NOT_IMPLEMENTED");
    }

    function acceptOwnership() external {
        // TODO
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------------ counter module

    function increment() external returns (uint256 newTotal) {
        // TODO
        revert("NOT_IMPLEMENTED");
    }

    function setLimit(uint256 newLimit) external {
        // TODO
        revert("NOT_IMPLEMENTED");
    }

    function total() external view returns (uint256) {
        // TODO
        return 0;
    }

    function limit() external view returns (uint256) {
        // TODO
        return 0;
    }

    function countOf(address account) external view returns (uint256) {
        // TODO
        return 0;
    }
}
