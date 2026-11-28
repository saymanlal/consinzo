// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract PausableSwitch {
    error NotOwner(address caller);
    error EnforcedPause();
    error ExpectedPause();

    event Paused(address account);
    event Unpaused(address account);
    event Pinged(address indexed account, uint256 totalPings);
    event PingsReset(uint256 clearedPings);

    address public owner;
    bool public paused;
    uint256 public totalPings;
    mapping(address => uint256) public pingsOf;

    modifier onlyOwner() {
        // TODO: revert with NotOwner(msg.sender) unless the caller is the owner
        _;
    }

    modifier whenNotPaused() {
        // TODO: revert with EnforcedPause() while paused
        _;
    }

    modifier whenPaused() {
        // TODO: revert with ExpectedPause() while not paused
        _;
    }

    constructor() {
        // TODO: the deployer is the owner
    }

    // TODO: attach the right modifiers to each function below and implement the bodies.

    function pause() external {
        revert("NOT_IMPLEMENTED");
    }

    function unpause() external {
        revert("NOT_IMPLEMENTED");
    }

    function ping() external {
        revert("NOT_IMPLEMENTED");
    }

    function emergencyReset() external {
        revert("NOT_IMPLEMENTED");
    }
}
