// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title StreamedRewards
/// @notice Staking pool that distributes notified rewards to stakers.
contract StreamedRewards {
    uint256 public constant DURATION = 7 days;

    error NotDistributor();
    error ZeroAmount();
    error InsufficientStake();
    error TransferFailed();

    event RewardNotified(uint256 amount, uint256 rewardRate, uint256 periodFinish);

    IERC20 public immutable stakeToken;
    IERC20 public immutable rewardToken;
    address public immutable distributor;

    uint256 public rewardRate;
    uint256 public periodFinish;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public totalStaked;

    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    constructor(address stakeToken_, address rewardToken_, address distributor_) {
        stakeToken = IERC20(stakeToken_);
        rewardToken = IERC20(rewardToken_);
        distributor = distributor_;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        return rewardPerTokenStored;
    }

    function earned(address account) public view returns (uint256) {
        return rewards[account] + (balanceOf[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18;
    }

    function stake(uint256 amount) external updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();
        totalStaked += amount;
        balanceOf[msg.sender] += amount;
        if (!stakeToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
    }

    function withdraw(uint256 amount) external updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();
        if (amount > balanceOf[msg.sender]) revert InsufficientStake();
        totalStaked -= amount;
        balanceOf[msg.sender] -= amount;
        if (!stakeToken.transfer(msg.sender, amount)) revert TransferFailed();
    }

    function getReward() external updateReward(msg.sender) returns (uint256 paid) {
        paid = rewards[msg.sender];
        if (paid > 0) {
            rewards[msg.sender] = 0;
            if (!rewardToken.transfer(msg.sender, paid)) revert TransferFailed();
        }
    }

    function notifyRewardAmount(uint256 amount) external {
        if (msg.sender != distributor) revert NotDistributor();
        if (amount == 0) revert ZeroAmount();
        if (!rewardToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        // TODO: the entire reward is credited to whoever is staked in this block.
        // rewardRate and periodFinish are never used.
        rewardPerTokenStored += (amount * 1e18) / totalStaked;
        emit RewardNotified(amount, rewardRate, periodFinish);
    }
}
