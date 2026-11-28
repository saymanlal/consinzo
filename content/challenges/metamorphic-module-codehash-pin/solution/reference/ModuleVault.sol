// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IModuleRegistry {
    /// @notice Current deployment behind a module id. Controlled by the module developer.
    function resolve(bytes32 id) external view returns (address);
}

interface IStrategyModule {
    function onAllocate() external payable;

    function withdrawTo(address to, uint256 amount) external;
}

/// @title ModuleVault
/// @notice Treasury that allocates ETH to audited strategy modules.
contract ModuleVault {
    error NotOwner();
    error NotApproved();
    error NotAContract();
    error CodeHashMismatch();

    event ModuleApproved(bytes32 indexed id, address module, bytes32 codeHash);
    event ModuleRevoked(bytes32 indexed id);
    event Allocated(bytes32 indexed id, address module, uint256 amount);
    event Recalled(bytes32 indexed id, address module, uint256 amount);

    address public immutable owner;
    IModuleRegistry public immutable registry;

    /// @dev keccak256 of the audited runtime code. Zero means "not approved".
    mapping(bytes32 => bytes32) public approvedCodeHash;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address registry_) {
        owner = msg.sender;
        registry = IModuleRegistry(registry_);
    }

    receive() external payable {}

    function isApproved(bytes32 id) public view returns (bool) {
        return approvedCodeHash[id] != bytes32(0);
    }

    function approveModule(bytes32 id, bytes32 expectedCodeHash) external onlyOwner {
        address module = registry.resolve(id);
        if (module.code.length == 0) revert NotAContract();
        // The owner states what was audited. If the developer swapped the code between the
        // audit and this transaction, the approval fails instead of blessing unknown code.
        if (module.codehash != expectedCodeHash) revert CodeHashMismatch();
        approvedCodeHash[id] = expectedCodeHash;
        emit ModuleApproved(id, module, module.codehash);
    }

    function revokeModule(bytes32 id) external onlyOwner {
        delete approvedCodeHash[id];
        emit ModuleRevoked(id);
    }

    function allocate(bytes32 id, uint256 amount) external {
        address module = _trustedModule(id);
        IStrategyModule(module).onAllocate{value: amount}();
        emit Allocated(id, module, amount);
    }

    function recall(bytes32 id, uint256 amount) external onlyOwner {
        address module = _trustedModule(id);
        IStrategyModule(module).withdrawTo(address(this), amount);
        emit Recalled(id, module, amount);
    }

    /// @dev Resolves an id and decides whether the code behind it may be trusted right now.
    function _trustedModule(bytes32 id) private view returns (address module) {
        bytes32 pinned = approvedCodeHash[id];
        if (pinned == bytes32(0)) revert NotApproved();
        module = registry.resolve(id);
        // Trust follows the code, not the identity. An account without code has hash 0 or
        // keccak256(""), neither of which can equal a pinned contract hash.
        if (module.codehash != pinned) revert CodeHashMismatch();
    }
}
