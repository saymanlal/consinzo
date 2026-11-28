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
        // TODO: Tokens held by the contract beyond totalStaked.
        revert("NOT_IMPLEMENTED");
    }

    function pendingRewards(address user) public view returns (uint256) {
        // TODO: Stored unclaimed rewards plus simple interest since the last checkpoint.
        revert("NOT_IMPLEMENTED");
    }

    function stake(uint256 amount) external {
        // TODO: Checkpoint, pull tokens, increase principal and totalStaked, emit Staked.
        revert("NOT_IMPLEMENTED");
    }

    function unstake(uint256 amount) external {
        // TODO: Checkpoint, reduce principal and totalStaked, return tokens, emit Unstaked.
        revert("NOT_IMPLEMENTED");
    }

    function claim() external returns (uint256 paid) {
        // TODO: Checkpoint, pay all pending rewards from the reward pool only, emit Claimed.
        revert("NOT_IMPLEMENTED");
    }
}
