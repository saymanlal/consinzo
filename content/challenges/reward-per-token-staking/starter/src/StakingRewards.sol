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

    function lastTimeRewardApplicable() public view returns (uint256) {
        // TODO: min(block.timestamp, periodFinish)
        revert("NOT_IMPLEMENTED");
    }

    function rewardPerToken() public view returns (uint256) {
        // TODO: Cumulative reward per staked token scaled by 1e18 (see README rule 2).
        revert("NOT_IMPLEMENTED");
    }

    function earned(address account) public view returns (uint256) {
        // TODO: Rewards owed to `account` right now (see README rule 3).
        revert("NOT_IMPLEMENTED");
    }

    // Every state-changing function below must first update the global accumulator and
    // settle the caller. An internal helper keeps that in one place.

    function stake(uint256 amount) external {
        // TODO: Update rewards, validate, pull staking tokens, update balances, emit Staked.
        revert("NOT_IMPLEMENTED");
    }

    function withdraw(uint256 amount) external {
        // TODO: Update rewards, validate, update balances, return staking tokens, emit Withdrawn.
        revert("NOT_IMPLEMENTED");
    }

    function getReward() public returns (uint256 reward) {
        // TODO: Update rewards, pay the caller's settled rewards (if any), emit RewardPaid.
        revert("NOT_IMPLEMENTED");
    }

    function exit() external {
        // TODO: Withdraw the caller's whole stake (if any), then getReward().
        revert("NOT_IMPLEMENTED");
    }

    function notifyRewardAmount(uint256 reward) external {
        // TODO: Only owner. Update the accumulator, pull `reward` from the owner, compute the new
        //       rewardRate (rolling over any undistributed remainder), reset the period, emit RewardAdded.
        revert("NOT_IMPLEMENTED");
    }
}
