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

    // The proxy declares no external functions. Whatever selector a user sends, there is
    // nothing here for it to collide with: routing depends on the caller alone.

    fallback() external payable {
        _route();
    }

    receive() external payable {
        _route();
    }

    function _route() private {
        if (msg.sender != _admin()) {
            _delegate(_implementation()); // does not return
        }
        bytes memory ret = _handleAdminCall();
        assembly {
            return(add(ret, 0x20), mload(ret))
        }
    }

    /// @dev The admin interface, dispatched by hand. Only reachable when msg.sender is the admin.
    function _handleAdminCall() private returns (bytes memory) {
        bytes4 selector = msg.sig;
        if (selector == 0xf851a440) {
            // admin()
            return abi.encode(_admin());
        }
        if (selector == 0x5c60da1b) {
            // implementation()
            return abi.encode(_implementation());
        }
        if (selector == 0x3659cfe6) {
            // upgradeTo(address)
            _setImplementation(abi.decode(msg.data[4:], (address)));
            return "";
        }
        if (selector == 0x8f283970) {
            // changeAdmin(address)
            address newAdmin = abi.decode(msg.data[4:], (address));
            if (newAdmin == address(0)) revert ZeroAddress();
            emit AdminChanged(_admin(), newAdmin);
            _setAdmin(newAdmin);
            return "";
        }
        // The admin never reaches the implementation, so admin and user call spaces are disjoint.
        revert AdminCannotFallback();
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
