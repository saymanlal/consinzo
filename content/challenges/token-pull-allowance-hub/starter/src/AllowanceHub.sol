// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20Minimal {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract AllowanceHub {
    /// @dev Packed into a single storage slot (160 + 48 + 48 bits).
    struct Allowance {
        uint160 amount;
        uint48 expiration;
        uint48 epoch;
    }

    struct Pull {
        address owner;
        address token;
        address to;
        uint160 amount;
    }

    /// @notice owner => token => spender => allowance
    mapping(address => mapping(address => mapping(address => Allowance))) public allowance;
    /// @notice owner => spender => current epoch
    mapping(address => mapping(address => uint48)) public nonces;

    event Approved(
        address indexed owner, address indexed token, address indexed spender, uint160 amount, uint48 expiration
    );
    event Revoked(address indexed owner, address indexed token, address indexed spender);
    event SpenderRevoked(address indexed owner, address indexed spender, uint48 newNonce);

    error ZeroAddress();
    error InvalidExpiration();
    error AllowanceRevoked();
    error AllowanceExpired();
    error InsufficientAllowance();
    error TransferFailed();

    function approve(address token, address spender, uint160 amount, uint48 expiration) external {
        // TODO: validate spender and expiration, then replace the allowance, stamped with the current epoch
        revert("NOT_IMPLEMENTED");
    }

    function revoke(address token, address spender) external {
        // TODO: delete the caller's allowance for (token, spender)
        revert("NOT_IMPLEMENTED");
    }

    function revokeSpender(address spender) external returns (uint48 newNonce) {
        // TODO: bump nonces[msg.sender][spender] and return the new value
        revert("NOT_IMPLEMENTED");
    }

    function transferFrom(address owner, address to, uint160 amount, address token) external {
        // TODO: checks in the documented order (recipient, epoch, expiry, amount)
        // TODO: decrease a finite allowance before calling the token
        // TODO: call token.transferFrom safely (no code, revert, false and missing return data)
        revert("NOT_IMPLEMENTED");
    }

    function batchTransferFrom(Pull[] calldata pulls) external {
        // TODO: apply the same logic to every entry; all or nothing
        revert("NOT_IMPLEMENTED");
    }

    function spendable(address owner, address token, address spender) external view returns (uint160) {
        // TODO: stored amount if the allowance is live and not expired, otherwise 0
        revert("NOT_IMPLEMENTED");
    }
}
