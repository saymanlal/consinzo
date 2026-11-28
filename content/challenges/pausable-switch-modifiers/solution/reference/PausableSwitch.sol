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

    address public immutable owner;
    bool public paused;
    uint256 public totalPings;
    mapping(address => uint256) public pingsOf;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ExpectedPause();
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // Modifiers run left to right, so onlyOwner is listed first: a non-owner
    // always sees NotOwner regardless of the pause state.

    function pause() external onlyOwner whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function ping() external whenNotPaused {
        pingsOf[msg.sender] += 1;
        uint256 total = totalPings + 1;
        totalPings = total;
        emit Pinged(msg.sender, total);
    }

    function emergencyReset() external onlyOwner whenPaused {
        uint256 cleared = totalPings;
        totalPings = 0;
        emit PingsReset(cleared);
    }
}
