// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract RewardFarm {
    error NotOwner();
    error DuplicatePool();
    error InvalidPool();
    error InsufficientBalance();
    error TransferFailed();

    event PoolAdded(uint256 indexed pid, address indexed lpToken, uint256 allocPoint);
    event PoolSet(uint256 indexed pid, uint256 allocPoint);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    struct PoolInfo {
        address lpToken;
        uint256 allocPoint;
        uint256 lastRewardTime;
        uint256 accRewardPerShare; // scaled by ACC_PRECISION
        uint256 totalStaked;
    }

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    uint256 public constant ACC_PRECISION = 1e18;

    IERC20 public immutable rewardToken;
    uint256 public immutable rewardPerSecond;
    uint256 public immutable startTime;
    address public immutable owner;

    uint256 public totalAllocPoint;
    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    mapping(address => bool) internal lpRegistered;

    constructor(address rewardToken_, uint256 rewardPerSecond_, uint256 startTime_) {
        rewardToken = IERC20(rewardToken_);
        rewardPerSecond = rewardPerSecond_;
        startTime = startTime_;
        owner = msg.sender;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function add(uint256 allocPoint, address lpToken) external returns (uint256 pid) {
        // TODO: Only owner, reject duplicates, update all pools first, then register the pool
        //       with lastRewardTime = max(now, startTime). Emit PoolAdded.
        revert("NOT_IMPLEMENTED");
    }

    function set(uint256 pid, uint256 allocPoint) external {
        // TODO: Only owner, update all pools first, then change the pool's points and totalAllocPoint.
        revert("NOT_IMPLEMENTED");
    }

    function updatePool(uint256 pid) public {
        // TODO: Bring accRewardPerShare and lastRewardTime of the pool up to date (README rule 2).
        revert("NOT_IMPLEMENTED");
    }

    function massUpdatePools() public {
        // TODO: updatePool for every pool.
        revert("NOT_IMPLEMENTED");
    }

    function pendingReward(uint256 pid, address user) external view returns (uint256) {
        // TODO: Claimable reward of `user`, including what accrued since the last pool update.
        revert("NOT_IMPLEMENTED");
    }

    function deposit(uint256 pid, uint256 amount) external {
        // TODO: Update the pool, pay pending rewards, pull LP tokens, update amount, totalStaked
        //       and rewardDebt. Emit Deposit.
        revert("NOT_IMPLEMENTED");
    }

    function withdraw(uint256 pid, uint256 amount) external {
        // TODO: Update the pool, check the stake, pay pending rewards, return LP tokens, update
        //       amount, totalStaked and rewardDebt. Emit Withdraw.
        revert("NOT_IMPLEMENTED");
    }

    function emergencyWithdraw(uint256 pid) external {
        // TODO: Return the caller's stake without rewards and reset the user record.
        revert("NOT_IMPLEMENTED");
    }
}
