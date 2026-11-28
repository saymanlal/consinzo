// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract TimelockVault {
    error ZeroAmount();
    error InvalidUnlockTime();
    error InvalidLock();
    error AlreadyWithdrawn();
    error StillLocked();
    error NothingToWithdraw();
    error TransferFailed();

    event Locked(address indexed user, uint256 indexed lockId, uint256 amount, uint256 unlockTime);
    event Extended(address indexed user, uint256 indexed lockId, uint256 newUnlockTime);
    event Withdrawn(address indexed user, uint256 indexed lockId, uint256 amount);

    struct Lock {
        uint256 amount;
        uint256 unlockTime;
        bool withdrawn;
    }

    IERC20 public immutable token;
    uint256 public totalLocked;

    mapping(address => Lock[]) internal locks;

    constructor(address token_) {
        token = IERC20(token_);
    }

    function lock(uint256 amount, uint256 unlockTime) external returns (uint256 lockId) {
        // TODO: Validate, append a Lock for msg.sender, pull the tokens, emit Locked, return the index.
        revert("NOT_IMPLEMENTED");
    }

    function extendLock(uint256 lockId, uint256 newUnlockTime) external {
        // TODO: Only to a strictly later time that is also in the future. Emit Extended.
        revert("NOT_IMPLEMENTED");
    }

    function withdraw(uint256 lockId) external {
        // TODO: Withdraw one matured lock of msg.sender. Emit Withdrawn.
        revert("NOT_IMPLEMENTED");
    }

    function withdrawMatured() external returns (uint256 total) {
        // TODO: Withdraw every matured, not yet withdrawn lock of msg.sender with one transfer.
        revert("NOT_IMPLEMENTED");
    }

    function lockCount(address user) external view returns (uint256) {
        return locks[user].length;
    }

    function getLock(address user, uint256 lockId)
        external
        view
        returns (uint256 amount, uint256 unlockTime, bool withdrawn)
    {
        // TODO: Return the stored lock, InvalidLock for an unknown id.
        revert("NOT_IMPLEMENTED");
    }

    function lockedBalance(address user) external view returns (uint256 sum) {
        // TODO: Sum of all locks of `user` that are not withdrawn.
        revert("NOT_IMPLEMENTED");
    }

    function withdrawableBalance(address user) external view returns (uint256 sum) {
        // TODO: Sum of all locks of `user` that are matured and not withdrawn.
        revert("NOT_IMPLEMENTED");
    }
}
