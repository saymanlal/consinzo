// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IBeacon {
    function implementation() external view returns (address);
}

contract UpgradeableBeacon is IBeacon {
    error NotOwner();
    error ZeroAddress();
    error NotContract(address target);

    event Upgraded(address indexed implementation);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    address public owner;
    address public implementation;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address implementation_, address owner_) {
        if (owner_ == address(0)) revert ZeroAddress();
        owner = owner_;
        emit OwnershipTransferred(address(0), owner_);
        _setImplementation(implementation_);
    }

    function upgradeTo(address newImplementation) external onlyOwner {
        _setImplementation(newImplementation);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function _setImplementation(address newImplementation) private {
        // Every proxy behind this beacon would silently do nothing if this had no code.
        if (newImplementation.code.length == 0) revert NotContract(newImplementation);
        implementation = newImplementation;
        emit Upgraded(newImplementation);
    }
}

contract BeaconProxy {
    error NotContract(address target);

    event BeaconUpgraded(address indexed beacon);

    // bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1)
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    constructor(address beacon, bytes memory initData) payable {
        if (beacon.code.length == 0) revert NotContract(beacon);
        address impl = IBeacon(beacon).implementation();
        if (impl.code.length == 0) revert NotContract(impl);

        bytes32 slot = BEACON_SLOT;
        assembly {
            sstore(slot, beacon)
        }
        emit BeaconUpgraded(beacon);

        if (initData.length != 0) {
            // Runs the implementation's initialiser against this proxy's storage.
            (bool ok, bytes memory ret) = impl.delegatecall(initData);
            if (!ok) {
                assembly {
                    revert(add(ret, 0x20), mload(ret))
                }
            }
        }
    }

    fallback() external payable {
        // The implementation is looked up on every call and never cached, so a beacon
        // upgrade takes effect for all proxies immediately.
        bytes32 slot = BEACON_SLOT;
        address beacon;
        assembly {
            beacon := sload(slot)
        }
        address impl = IBeacon(beacon).implementation();

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
