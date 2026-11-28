// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract FixedAprStaking {
    error ZeroAmount();
    error InsufficientStake();
    error InsufficientRewards();
    error NothingToClaim();
    error TransferFailed();

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);

    struct Account {
        uint256 principal; // tokens currently staked
        uint256 accrued; // rewards checkpointed but not yet claimed
        uint256 lastUpdate; // timestamp of the last checkpoint
    }

    uint256 public constant BPS = 10_000;
    uint256 public constant YEAR = 365 days;

    IERC20 public immutable token;
    uint256 public immutable aprBps;
    uint256 public totalStaked;

    mapping(address => Account) internal accounts;

    constructor(address token_, uint256 aprBps_) {
        token = IERC20(token_);
        aprBps = aprBps_;
    }

    function stakedOf(address user) external view returns (uint256) {
        return accounts[user].principal;
    }

    function rewardPool() public view returns (uint256) {
        return token.balanceOf(address(this)) - totalStaked;
    }

    function pendingRewards(address user) public view returns (uint256) {
        Account storage a = accounts[user];
        uint256 elapsed = block.timestamp - a.lastUpdate;
        return a.accrued + (a.principal * aprBps * elapsed) / (BPS * YEAR);
    }

    /// @dev Folds interest earned so far into `accrued`. Must run before the principal changes.
    function _checkpoint(Account storage a, address user) private {
        a.accrued = pendingRewards(user);
        a.lastUpdate = block.timestamp;
    }

    function stake(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        Account storage a = accounts[msg.sender];
        _checkpoint(a, msg.sender);
        a.principal += amount;
        totalStaked += amount;
        if (!token.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        Account storage a = accounts[msg.sender];
        if (amount > a.principal) revert InsufficientStake();
        _checkpoint(a, msg.sender);
        a.principal -= amount;
        totalStaked -= amount;
        if (!token.transfer(msg.sender, amount)) revert TransferFailed();
        emit Unstaked(msg.sender, amount);
    }

    function claim() external returns (uint256 paid) {
        Account storage a = accounts[msg.sender];
        _checkpoint(a, msg.sender);
        paid = a.accrued;
        if (paid == 0) revert NothingToClaim();
        // Rewards may only come from the surplus, never from anybody's principal.
        if (paid > rewardPool()) revert InsufficientRewards();
        a.accrued = 0;
        if (!token.transfer(msg.sender, paid)) revert TransferFailed();
        emit Claimed(msg.sender, paid);
    }
}
