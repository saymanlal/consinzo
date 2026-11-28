// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Minimal ERC-1967 proxy. All calls are forwarded to the implementation with
/// delegatecall; the upgrade logic lives in the implementation (UUPS style).
contract VaultProxy {
    bytes32 internal constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    constructor(address implementation_, bytes memory initData) payable {
        require(implementation_.code.length != 0, "NOT_A_CONTRACT");
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, implementation_)
        }
        if (initData.length != 0) {
            (bool ok, ) = implementation_.delegatecall(initData);
            require(ok, "INIT_FAILED");
        }
    }

    fallback() external payable {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            let impl := sload(slot)
            calldatacopy(0, 0, calldatasize())
            let ok := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch ok
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    receive() external payable {}
}

/// @notice Logic contract for an ETH vault with per-user balances. Meant to be used
/// through `VaultProxy`; its own storage is not supposed to matter.
contract VaultLogic {
    error AlreadyInitialized();
    error ZeroAddress();
    error NotOwner();
    error NotProxy();
    error NotAContract();
    error UpgradeCallFailed();
    error InsufficientBalance();
    error TransferFailed();

    event Upgraded(address indexed implementation);

    bytes32 internal constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address public owner;
    bool public initialized;
    mapping(address => uint256) public balanceOf;

    /// @dev Address of the implementation contract itself. Immutables are part of the code,
    /// so the value is the same whether the code runs directly or through a proxy.
    address private immutable __self = address(this);

    /// @dev Passes only when executing via delegatecall, i.e. through a proxy.
    modifier onlyProxy() {
        if (address(this) == __self) revert NotProxy();
        _;
    }

    /// @dev Runs once, in the implementation's own storage. It consumes the initializer so
    /// nobody can ever become owner of the implementation. Proxies are unaffected: they
    /// have separate storage and never execute this constructor.
    constructor() {
        initialized = true;
    }

    function initialize(address owner_) external {
        if (initialized) revert AlreadyInitialized();
        if (owner_ == address(0)) revert ZeroAddress();
        initialized = true;
        owner = owner_;
    }

    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external {
        if (amount > balanceOf[msg.sender]) revert InsufficientBalance();
        balanceOf[msg.sender] -= amount;
        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    function implementation() external view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    /// @notice Point the proxy at `newImplementation` and optionally run a migration on it.
    /// @dev `onlyProxy` is checked first: the delegatecall below must never execute in the
    /// implementation's own context, whoever the caller is.
    function upgradeToAndCall(address newImplementation, bytes calldata data) external onlyProxy {
        if (msg.sender != owner) revert NotOwner();
        if (newImplementation.code.length == 0) revert NotAContract();

        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
        emit Upgraded(newImplementation);

        if (data.length != 0) {
            (bool ok, ) = newImplementation.delegatecall(data);
            if (!ok) revert UpgradeCallFailed();
        }
    }
}
