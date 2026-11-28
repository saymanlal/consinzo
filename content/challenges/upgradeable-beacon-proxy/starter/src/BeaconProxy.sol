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

    constructor(address implementation_, address owner_) {
        // TODO: validate both arguments and store them.
    }

    function upgradeTo(address newImplementation) external {
        // TODO: owner only, target must have code, emit Upgraded.
        revert("NOT_IMPLEMENTED");
    }

    function transferOwnership(address newOwner) external {
        // TODO: owner only, no zero address, emit OwnershipTransferred.
        revert("NOT_IMPLEMENTED");
    }
}

contract BeaconProxy {
    error NotContract(address target);

    event BeaconUpgraded(address indexed beacon);

    // bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1)
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    constructor(address beacon, bytes memory initData) payable {
        // TODO: validate the beacon and its current implementation, store the beacon in
        //       BEACON_SLOT, emit BeaconUpgraded, delegatecall initData when not empty.
    }

    fallback() external payable {
        // TODO: ask the beacon for the implementation and delegate the call to it.
        revert("NOT_IMPLEMENTED");
    }
}
