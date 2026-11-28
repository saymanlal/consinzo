// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract StakingRewards {
    error NotOwner();
    error ZeroAmount();
    error InsufficientBalance();
    error RewardTooSmall();
    error TransferFailed();

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    uint256 internal constant PRECISION = 1e18;

    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;
    address public immutable owner;
    /// @notice Length of every reward period in seconds.
    uint256 public immutable duration;

    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(address stakingToken_, address rewardsToken_, uint256 duration_) {
        stakingToken = IERC20(stakingToken_);
        rewardsToken = IERC20(rewardsToken_);
        duration = duration_;
        owner = msg.sender;
    }

    /// @dev Brings the global accumulator up to date and settles `account` (skipped for address(0)).
    function _updateReward(address account) private {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) return rewardPerTokenStored;
        return
            rewardPerTokenStored +
            ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * PRECISION) /
            totalSupply;
    }

    function earned(address account) public view returns (uint256) {
        return
            (balanceOf[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) /
            PRECISION +
            rewards[account];
    }

    // Every state-changing function below must first update the global accumulator and
    // settle the caller. An internal helper keeps that in one place.

    function stake(uint256 amount) external {
        _updateReward(msg.sender);
        if (amount == 0) revert ZeroAmount();
        totalSupply += amount;
        balanceOf[msg.sender] += amount;
        if (!stakingToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        _withdraw(amount);
    }

    function _withdraw(uint256 amount) private {
        _updateReward(msg.sender);
        if (amount == 0) revert ZeroAmount();
        if (amount > balanceOf[msg.sender]) revert InsufficientBalance();
        totalSupply -= amount;
        balanceOf[msg.sender] -= amount;
        if (!stakingToken.transfer(msg.sender, amount)) revert TransferFailed();
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public returns (uint256 reward) {
        _updateReward(msg.sender);
        reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            if (!rewardsToken.transfer(msg.sender, reward)) revert TransferFailed();
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {
        uint256 staked = balanceOf[msg.sender];
        if (staked > 0) _withdraw(staked);
        getReward();
    }

    function notifyRewardAmount(uint256 reward) external {
        if (msg.sender != owner) revert NotOwner();
        _updateReward(address(0));
        if (!rewardsToken.transferFrom(msg.sender, address(this), reward)) revert TransferFailed();

        if (block.timestamp >= periodFinish) {
            rewardRate = reward / duration;
        } else {
            // The part of the running period that has not been streamed yet is re-spread
            // together with the new amount over a fresh full period.
            uint256 leftover = (periodFinish - block.timestamp) * rewardRate;
            rewardRate = (reward + leftover) / duration;
        }
        if (rewardRate == 0) revert RewardTooSmall();

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + duration;
        emit RewardAdded(reward);
    }
}
