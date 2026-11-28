// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract StorageBox {
    error NotOwner(address caller);

    event ValueChanged(uint256 oldValue, uint256 newValue);

    address public owner;
    uint256 public updateCount;
    uint256 private _value;

    constructor(uint256 initialValue) {
        // TODO: record the deployer as owner and store initialValue
    }

    function get() external view returns (uint256) {
        // TODO: return the stored value
        return 0;
    }

    function set(uint256 newValue) external {
        // TODO: revert with NotOwner(msg.sender) for non-owners,
        // otherwise store newValue, bump updateCount and emit ValueChanged
        revert("NOT_IMPLEMENTED");
    }
}
