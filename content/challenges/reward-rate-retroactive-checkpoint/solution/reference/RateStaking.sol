// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title RateStaking
/// @notice Streams `rewardRate` reward tokens per second to stakers, pro rata to stake.
contract RateStaking {
    error NotOwner();
    error ZeroAmount();
    error InsufficientStake();
    error TransferFailed();

    event RewardRateChanged(uint256 oldRate, uint256 newRate);

    IERC20 public immutable stakeToken;
    IERC20 public immutable rewardToken;
    address public immutable owner;

    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public totalStaked;

    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    constructor(address stakeToken_, address rewardToken_, uint256 rewardRate_) {
        stakeToken = IERC20(stakeToken_);
        rewardToken = IERC20(rewardToken_);
        owner = msg.sender;
        rewardRate = rewardRate_;
        lastUpdateTime = block.timestamp;
    }

    /// @dev Folds the elapsed interval into the accumulator at the current rate.
    function _checkpoint() internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
    }

    modifier updateReward(address account) {
        _checkpoint();
        rewards[account] = earned(account);
        userRewardPerTokenPaid[account] = rewardPerTokenStored;
        _;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) return rewardPerTokenStored;
        return rewardPerTokenStored + ((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalStaked;
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

    function claim() external updateReward(msg.sender) returns (uint256 paid) {
        paid = rewards[msg.sender];
        if (paid > 0) {
            rewards[msg.sender] = 0;
            if (!rewardToken.transfer(msg.sender, paid)) revert TransferFailed();
        }
    }

    function setRewardRate(uint256 newRate) external {
        if (msg.sender != owner) revert NotOwner();
        // Settle [lastUpdateTime, now] at the old rate first. After this the accumulator is
        // current and the new rate only applies to time that has not happened yet.
        _checkpoint();
        emit RewardRateChanged(rewardRate, newRate);
        rewardRate = newRate;
    }
}
