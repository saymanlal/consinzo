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

    /// @dev Loads a live (existing, not withdrawn) lock of `user`.
    function _liveLock(address user, uint256 lockId) private view returns (Lock storage l) {
        if (lockId >= locks[user].length) revert InvalidLock();
        l = locks[user][lockId];
        if (l.withdrawn) revert AlreadyWithdrawn();
    }

    function lock(uint256 amount, uint256 unlockTime) external returns (uint256 lockId) {
        if (amount == 0) revert ZeroAmount();
        if (unlockTime <= block.timestamp) revert InvalidUnlockTime();
        lockId = locks[msg.sender].length;
        locks[msg.sender].push(Lock({amount: amount, unlockTime: unlockTime, withdrawn: false}));
        totalLocked += amount;
        if (!token.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        emit Locked(msg.sender, lockId, amount, unlockTime);
    }

    function extendLock(uint256 lockId, uint256 newUnlockTime) external {
        Lock storage l = _liveLock(msg.sender, lockId);
        if (newUnlockTime <= l.unlockTime || newUnlockTime <= block.timestamp) revert InvalidUnlockTime();
        l.unlockTime = newUnlockTime;
        emit Extended(msg.sender, lockId, newUnlockTime);
    }

    function withdraw(uint256 lockId) external {
        Lock storage l = _liveLock(msg.sender, lockId);
        if (block.timestamp < l.unlockTime) revert StillLocked();
        uint256 amount = l.amount;
        l.withdrawn = true;
        totalLocked -= amount;
        if (!token.transfer(msg.sender, amount)) revert TransferFailed();
        emit Withdrawn(msg.sender, lockId, amount);
    }

    function withdrawMatured() external returns (uint256 total) {
        Lock[] storage list = locks[msg.sender];
        uint256 n = list.length;
        for (uint256 i = 0; i < n; i++) {
            Lock storage l = list[i];
            if (!l.withdrawn && block.timestamp >= l.unlockTime) {
                l.withdrawn = true;
                total += l.amount;
                emit Withdrawn(msg.sender, i, l.amount);
            }
        }
        if (total == 0) revert NothingToWithdraw();
        totalLocked -= total;
        if (!token.transfer(msg.sender, total)) revert TransferFailed();
    }

    function lockCount(address user) external view returns (uint256) {
        return locks[user].length;
    }

    function getLock(address user, uint256 lockId)
        external
        view
        returns (uint256 amount, uint256 unlockTime, bool withdrawn)
    {
        if (lockId >= locks[user].length) revert InvalidLock();
        Lock storage l = locks[user][lockId];
        return (l.amount, l.unlockTime, l.withdrawn);
    }

    function lockedBalance(address user) external view returns (uint256 sum) {
        Lock[] storage list = locks[user];
        for (uint256 i = 0; i < list.length; i++) {
            if (!list[i].withdrawn) sum += list[i].amount;
        }
    }

    function withdrawableBalance(address user) external view returns (uint256 sum) {
        Lock[] storage list = locks[user];
        for (uint256 i = 0; i < list.length; i++) {
            if (!list[i].withdrawn && block.timestamp >= list[i].unlockTime) sum += list[i].amount;
        }
    }
}
