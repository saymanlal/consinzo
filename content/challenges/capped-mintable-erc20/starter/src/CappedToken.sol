// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title CappedToken
/// @notice Owner-mintable token with an immutable ceiling on total supply.
contract CappedToken {
    string public constant name = "Capped Token";
    string public constant symbol = "CAP";
    uint8 public constant decimals = 18;

    address public immutable owner;
    uint256 public immutable cap;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    event Transfer(address indexed from, address indexed to, uint256 value);

    error ZeroCap();
    error NotOwner();
    error ZeroAddress();
    error CapExceeded();
    error InsufficientBalance();

    constructor(uint256 cap_) {
        // TODO: Revert with ZeroCap() when cap_ is zero
        cap = cap_;
        owner = msg.sender;
    }

    function remainingMintable() public view returns (uint256) {
        // TODO: Return how many more tokens can be minted before the cap is reached
        revert("NOT_IMPLEMENTED");
    }

    function mint(address to, uint256 amount) external {
        // TODO: Owner only; reject address(0); enforce the cap without overflowing; emit Transfer
        revert("NOT_IMPLEMENTED");
    }

    function burn(uint256 amount) external {
        // TODO: Check the caller's balance, reduce balance and totalSupply, emit Transfer to address(0)
        revert("NOT_IMPLEMENTED");
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        // TODO: Reject address(0), check balance, move tokens, emit Transfer, return true
        revert("NOT_IMPLEMENTED");
    }
}
