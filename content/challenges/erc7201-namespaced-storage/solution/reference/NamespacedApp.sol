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

    // keccak256(abi.encode(uint256(keccak256("consinzo.storage.Ownable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OWNABLE_LOCATION = 0xe0730a31143b6cf338774ec851375549b766909386163b0867143dc9306ff100;
    // keccak256(abi.encode(uint256(keccak256("consinzo.storage.Counter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant COUNTER_LOCATION = 0x5f8a01231cfda993522d85736cafcc8a28979d38def8a7e59e762ed9fbf5f200;

    // The constants are literals so that they can be used in assembly. The constructor
    // re-derives them once at deployment, which turns a typo into a failed deployment.
    constructor() {
        assert(OWNABLE_LOCATION == _erc7201("consinzo.storage.Ownable"));
        assert(COUNTER_LOCATION == _erc7201("consinzo.storage.Counter"));
    }

    function _erc7201(string memory id) private pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256(bytes(id))) - 1)) & ~bytes32(uint256(0xff));
    }

    function _ownable() private pure returns (OwnableStorage storage $) {
        assembly {
            $.slot := OWNABLE_LOCATION
        }
    }

    function _counter() private pure returns (CounterStorage storage $) {
        assembly {
            $.slot := COUNTER_LOCATION
        }
    }

    /// @notice ERC-7201 location of the namespace `id`.
    function namespaceSlot(string calldata id) external pure returns (bytes32) {
        return _erc7201(id);
    }

    /// @notice Raw storage read. Used by the tests to inspect the layout. Do not change.
    function readSlot(bytes32 slot) external view returns (bytes32 value) {
        assembly {
            value := sload(slot)
        }
    }

    // ---------------------------------------------------------------- ownership module

    modifier onlyOwner() {
        if (msg.sender != _ownable().owner) revert NotOwner();
        _;
    }

    function initialize(address initialOwner) external {
        OwnableStorage storage $ = _ownable();
        if (initialOwner == address(0)) revert ZeroAddress();
        // The owner can never become zero again, so it doubles as the "initialised" flag.
        if ($.owner != address(0)) revert AlreadyInitialized();
        $.owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() external view returns (address) {
        return _ownable().owner;
    }

    function pendingOwner() external view returns (address) {
        return _ownable().pendingOwner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        OwnableStorage storage $ = _ownable();
        $.pendingOwner = newOwner;
        emit OwnershipTransferStarted($.owner, newOwner);
    }

    function acceptOwnership() external {
        OwnableStorage storage $ = _ownable();
        // With no transfer pending this compares against address(0), which no caller is.
        if (msg.sender != $.pendingOwner) revert NotPendingOwner();
        emit OwnershipTransferred($.owner, msg.sender);
        $.owner = msg.sender;
        $.pendingOwner = address(0);
    }

    // ------------------------------------------------------------------ counter module

    function increment() external returns (uint256 newTotal) {
        CounterStorage storage $ = _counter();
        uint256 current = $.total;
        uint256 cap = $.limit;
        if (cap != 0 && current >= cap) revert LimitReached();
        newTotal = current + 1;
        $.total = newTotal;
        $.perUser[msg.sender] += 1;
        emit Incremented(msg.sender, newTotal);
    }

    function setLimit(uint256 newLimit) external onlyOwner {
        _counter().limit = newLimit;
        emit LimitSet(newLimit);
    }

    function total() external view returns (uint256) {
        return _counter().total;
    }

    function limit() external view returns (uint256) {
        return _counter().limit;
    }

    function countOf(address account) external view returns (uint256) {
        return _counter().perUser[account];
    }
}
