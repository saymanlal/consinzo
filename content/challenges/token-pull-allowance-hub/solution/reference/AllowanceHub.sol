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

    // ---------------------------------------------------------------- owner side

    function approve(address token, address spender, uint160 amount, uint48 expiration) external {
        if (spender == address(0)) revert ZeroAddress();
        if (expiration < block.timestamp) revert InvalidExpiration();
        // Stamp the allowance with the current epoch; bumping the nonce later kills it.
        allowance[msg.sender][token][spender] =
            Allowance({amount: amount, expiration: expiration, epoch: nonces[msg.sender][spender]});
        emit Approved(msg.sender, token, spender, amount, expiration);
    }

    function revoke(address token, address spender) external {
        delete allowance[msg.sender][token][spender];
        emit Revoked(msg.sender, token, spender);
    }

    function revokeSpender(address spender) external returns (uint48 newNonce) {
        // O(1) revocation of every token: allowances stamped with the old epoch are dead.
        newNonce = nonces[msg.sender][spender] + 1;
        nonces[msg.sender][spender] = newNonce;
        emit SpenderRevoked(msg.sender, spender, newNonce);
    }

    // ---------------------------------------------------------------- spender side

    function transferFrom(address owner, address to, uint160 amount, address token) external {
        _pull(owner, to, amount, token);
    }

    function batchTransferFrom(Pull[] calldata pulls) external {
        for (uint256 i = 0; i < pulls.length; i++) {
            Pull calldata p = pulls[i];
            _pull(p.owner, p.to, p.amount, p.token);
        }
    }

    // ---------------------------------------------------------------- views

    function spendable(address owner, address token, address spender) external view returns (uint160) {
        Allowance memory a = allowance[owner][token][spender];
        if (a.epoch != nonces[owner][spender] || block.timestamp > a.expiration) return 0;
        return a.amount;
    }

    // ---------------------------------------------------------------- internals

    function _pull(address owner, address to, uint160 amount, address token) internal {
        if (to == address(0)) revert ZeroAddress();

        Allowance storage a = allowance[owner][token][msg.sender];
        if (a.epoch != nonces[owner][msg.sender]) revert AllowanceRevoked();
        if (block.timestamp > a.expiration) revert AllowanceExpired();

        uint160 allowed = a.amount;
        if (amount > allowed) revert InsufficientAllowance();
        if (allowed != type(uint160).max) {
            // Effects before the external call: a token that re-enters sees the reduced
            // allowance and cannot spend the same units twice.
            unchecked {
                a.amount = allowed - amount;
            }
        }

        _safeTransferFrom(token, owner, to, amount);
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        // A call to an address without code succeeds and returns nothing, which would look
        // exactly like a token that returns no data.
        if (token.code.length == 0) revert TransferFailed();
        (bool ok, bytes memory ret) =
            token.call(abi.encodeWithSelector(IERC20Minimal.transferFrom.selector, from, to, amount));
        if (!ok) revert TransferFailed();
        if (ret.length != 0) {
            if (ret.length != 32 || abi.decode(ret, (uint256)) != 1) revert TransferFailed();
        }
    }
}
