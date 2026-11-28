// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract StorageBox {
    error NotOwner(address caller);

    event ValueChanged(uint256 oldValue, uint256 newValue);

    /// @notice The deployer. Immutable because ownership is never transferred.
    address public immutable owner;
    uint256 public updateCount;
    uint256 private _value;

    constructor(uint256 initialValue) {
        owner = msg.sender;
        _value = initialValue;
    }

    function get() external view returns (uint256) {
        return _value;
    }

    function set(uint256 newValue) external {
        // Authorization comes first so a rejected call cannot change any state.
        if (msg.sender != owner) revert NotOwner(msg.sender);

        uint256 oldValue = _value;
        _value = newValue;
        updateCount += 1;

        emit ValueChanged(oldValue, newValue);
    }
}
