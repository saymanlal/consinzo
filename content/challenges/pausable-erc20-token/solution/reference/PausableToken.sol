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
        if (msg.sender != owner) revert NotOwner();
        if (paused) revert EnforcedPause();
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external {
        if (msg.sender != owner) revert NotOwner();
        if (!paused) revert ExpectedPause();
        paused = false;
        emit Unpaused(msg.sender);
    }

    function mint(address to, uint256 amount) external {
        // Deliberately not gated by the pause: the owner may need to mint during an incident.
        if (msg.sender != owner) revert NotOwner();
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount; // bounded by totalSupply
        }
        emit Transfer(address(0), to, amount);
    }

    function burn(uint256 amount) external {
        _requireNotPaused();
        uint256 balance = balanceOf[msg.sender];
        if (balance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[msg.sender] = balance - amount;
            totalSupply -= amount;
        }
        emit Transfer(msg.sender, address(0), amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _requireNotPaused();
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        // Approvals move no tokens, so they stay available (holders can revoke during a pause).
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _requireNotPaused();
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) {
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    function _requireNotPaused() internal view {
        if (paused) revert EnforcedPause();
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        uint256 balance = balanceOf[from];
        if (balance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = balance - amount;
            balanceOf[to] += amount; // bounded by totalSupply
        }
        emit Transfer(from, to, amount);
    }
}
