// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// Management functions of the proxy. They are only reachable for the admin.
interface ITransparentProxy {
    function admin() external returns (address);
    function implementation() external returns (address);
    function changeAdmin(address newAdmin) external;
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
}

contract TransparentProxy {
    error NotContract(address target);
    error ZeroAdmin();
    error AdminCannotFallback();

    event Upgraded(address indexed implementation);
    event AdminChanged(address previousAdmin, address newAdmin);

    // bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
    bytes32 internal constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    // bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    constructor(address implementation_, address admin_, bytes memory initData) payable {
        _setAdmin(admin_);
        _upgradeToAndCall(implementation_, initData);
    }

    /// The management functions are deliberately not declared as external functions.
    /// Declared functions would shadow the implementation for every caller; dispatching
    /// here lets the caller's identity decide which side handles the selector.
    fallback() external payable {
        if (msg.sender != _getAdmin()) {
            _delegate(_getImplementation());
        }

        bytes4 selector = msg.sig;
        bytes memory ret;
        if (selector == ITransparentProxy.admin.selector) {
            ret = abi.encode(_getAdmin());
        } else if (selector == ITransparentProxy.implementation.selector) {
            ret = abi.encode(_getImplementation());
        } else if (selector == ITransparentProxy.changeAdmin.selector) {
            address newAdmin = abi.decode(msg.data[4:], (address));
            emit AdminChanged(_getAdmin(), newAdmin);
            _setAdmin(newAdmin);
        } else if (selector == ITransparentProxy.upgradeTo.selector) {
            address newImplementation = abi.decode(msg.data[4:], (address));
            _upgradeToAndCall(newImplementation, "");
        } else if (selector == ITransparentProxy.upgradeToAndCall.selector) {
            (address newImplementation, bytes memory data) = abi.decode(msg.data[4:], (address, bytes));
            _upgradeToAndCall(newImplementation, data);
        } else {
            // The admin can never reach the implementation through the proxy.
            revert AdminCannotFallback();
        }

        assembly {
            return(add(ret, 0x20), mload(ret))
        }
    }

    function _getAdmin() private view returns (address a) {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            a := sload(slot)
        }
    }

    function _setAdmin(address newAdmin) private {
        if (newAdmin == address(0)) revert ZeroAdmin();
        bytes32 slot = ADMIN_SLOT;
        assembly {
            sstore(slot, newAdmin)
        }
    }

    function _getImplementation() private view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    function _upgradeToAndCall(address newImplementation, bytes memory data) private {
        if (newImplementation.code.length == 0) revert NotContract(newImplementation);
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
        emit Upgraded(newImplementation);

        if (data.length != 0) {
            (bool ok, bytes memory ret) = newImplementation.delegatecall(data);
            if (!ok) {
                assembly {
                    revert(add(ret, 0x20), mload(ret))
                }
            }
        }
    }

    /// Delegates the current call and never returns to Solidity code.
    function _delegate(address impl) private {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let ok := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch ok
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
