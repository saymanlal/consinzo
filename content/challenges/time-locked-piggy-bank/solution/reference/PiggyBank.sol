// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract PiggyBank {
    error NotOwner(address caller);
    error UnlockTimeNotInFuture(uint256 unlockTime);
    error ZeroDeposit();
    error StillLocked(uint256 unlockTime);
    error NothingToWithdraw();
    error TransferFailed();

    event Deposited(address indexed from, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);

    address public immutable owner;
    uint256 public immutable unlockTime;
    uint256 public totalDeposited;

    constructor(uint256 unlockTime_) {
        // An unlock time that is not in the future would make the lock meaningless.
        if (unlockTime_ <= block.timestamp) revert UnlockTimeNotInFuture(unlockTime_);
        unlockTime = unlockTime_;
        owner = msg.sender;
    }

    receive() external payable {
        _deposit();
    }

    function deposit() external payable {
        _deposit();
    }

    function withdraw() external {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        if (block.timestamp < unlockTime) revert StillLocked(unlockTime);

        uint256 amount = address(this).balance;
        if (amount == 0) revert NothingToWithdraw();

        (bool ok,) = owner.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit Withdrawn(owner, amount);
    }

    function isUnlocked() external view returns (bool) {
        return block.timestamp >= unlockTime;
    }

    function secondsUntilUnlock() external view returns (uint256) {
        // Guard the subtraction: after the unlock time it would underflow.
        if (block.timestamp >= unlockTime) return 0;
        return unlockTime - block.timestamp;
    }

    function _deposit() internal {
        if (msg.value == 0) revert ZeroDeposit();
        totalDeposited += msg.value;
        emit Deposited(msg.sender, msg.value);
    }
}
