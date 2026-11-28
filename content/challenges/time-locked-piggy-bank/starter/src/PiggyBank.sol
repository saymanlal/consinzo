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

    address public owner;
    uint256 public unlockTime;
    uint256 public totalDeposited;

    constructor(uint256 unlockTime_) {
        // TODO: require unlockTime_ > block.timestamp, store it, record the deployer as owner
    }

    receive() external payable {
        // TODO: same behaviour as deposit()
        revert("NOT_IMPLEMENTED");
    }

    function deposit() external payable {
        // TODO: reject zero value, update totalDeposited, emit Deposited
        revert("NOT_IMPLEMENTED");
    }

    function withdraw() external {
        // TODO: owner only, only once unlocked, send the whole balance, emit Withdrawn
        revert("NOT_IMPLEMENTED");
    }

    function isUnlocked() external view returns (bool) {
        // TODO
        return false;
    }

    function secondsUntilUnlock() external view returns (uint256) {
        // TODO: 0 once unlocked, never revert
        return 0;
    }
}
