// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title PausableToken
/// @notice ERC-20 with an owner-controlled pause on token movement.
contract PausableToken {
    string public constant name = "Pausable Token";
    string public constant symbol = "PSE";
    uint8 public constant decimals = 18;

    address public immutable owner;
    bool public paused;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Paused(address account);
    event Unpaused(address account);

    error NotOwner();
    error EnforcedPause();
    error ExpectedPause();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();

    constructor() {
        owner = msg.sender;
    }

    function pause() external {
        // TODO: Owner only; revert if already paused; set the flag and emit Paused
        revert("NOT_IMPLEMENTED");
    }

    function unpause() external {
        // TODO: Owner only; revert if not paused; clear the flag and emit Unpaused
        revert("NOT_IMPLEMENTED");
    }

    function mint(address to, uint256 amount) external {
        // TODO: Owner only, allowed while paused; reject address(0); emit Transfer from address(0)
        revert("NOT_IMPLEMENTED");
    }

    function burn(uint256 amount) external {
        // TODO: Blocked while paused; check balance; reduce balance and supply; emit Transfer to address(0)
        revert("NOT_IMPLEMENTED");
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        // TODO: Blocked while paused; otherwise a standard checked transfer
        revert("NOT_IMPLEMENTED");
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        // TODO: Allowed while paused; reject address(0); set allowance; emit Approval
        revert("NOT_IMPLEMENTED");
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        // TODO: Blocked while paused; consume allowance (keep type(uint256).max); then transfer
        revert("NOT_IMPLEMENTED");
    }

}
