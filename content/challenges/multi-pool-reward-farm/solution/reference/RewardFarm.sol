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

    function _pool(uint256 pid) private view returns (PoolInfo storage) {
        if (pid >= poolInfo.length) revert InvalidPool();
        return poolInfo[pid];
    }

    /// @dev accRewardPerShare as it would be after updatePool, without writing.
    function _currentAcc(PoolInfo storage pool) private view returns (uint256 acc) {
        acc = pool.accRewardPerShare;
        if (block.timestamp > pool.lastRewardTime && pool.totalStaked != 0 && pool.allocPoint != 0) {
            uint256 reward = ((block.timestamp - pool.lastRewardTime) * rewardPerSecond * pool.allocPoint) /
                totalAllocPoint;
            acc += (reward * ACC_PRECISION) / pool.totalStaked;
        }
    }

    function _payReward(address to, uint256 amount) private {
        if (amount == 0) return;
        if (!rewardToken.transfer(to, amount)) revert TransferFailed();
    }

    function add(uint256 allocPoint, address lpToken) external returns (uint256 pid) {
        if (msg.sender != owner) revert NotOwner();
        if (lpRegistered[lpToken]) revert DuplicatePool();
        // Settle every pool with the old weights before the denominator changes.
        massUpdatePools();

        lpRegistered[lpToken] = true;
        totalAllocPoint += allocPoint;
        pid = poolInfo.length;
        poolInfo.push(
            PoolInfo({
                lpToken: lpToken,
                allocPoint: allocPoint,
                lastRewardTime: block.timestamp > startTime ? block.timestamp : startTime,
                accRewardPerShare: 0,
                totalStaked: 0
            })
        );
        emit PoolAdded(pid, lpToken, allocPoint);
    }

    function set(uint256 pid, uint256 allocPoint) external {
        if (msg.sender != owner) revert NotOwner();
        PoolInfo storage pool = _pool(pid);
        massUpdatePools();
        totalAllocPoint = totalAllocPoint - pool.allocPoint + allocPoint;
        pool.allocPoint = allocPoint;
        emit PoolSet(pid, allocPoint);
    }

    function updatePool(uint256 pid) public {
        PoolInfo storage pool = _pool(pid);
        if (block.timestamp <= pool.lastRewardTime) return;
        pool.accRewardPerShare = _currentAcc(pool);
        pool.lastRewardTime = block.timestamp;
    }

    function massUpdatePools() public {
        uint256 n = poolInfo.length;
        for (uint256 pid = 0; pid < n; pid++) {
            updatePool(pid);
        }
    }

    function pendingReward(uint256 pid, address user) external view returns (uint256) {
        PoolInfo storage pool = _pool(pid);
        UserInfo storage u = userInfo[pid][user];
        return (u.amount * _currentAcc(pool)) / ACC_PRECISION - u.rewardDebt;
    }

    function deposit(uint256 pid, uint256 amount) external {
        updatePool(pid);
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage u = userInfo[pid][msg.sender];

        uint256 pending = (u.amount * pool.accRewardPerShare) / ACC_PRECISION - u.rewardDebt;
        if (amount > 0) {
            u.amount += amount;
            pool.totalStaked += amount;
        }
        u.rewardDebt = (u.amount * pool.accRewardPerShare) / ACC_PRECISION;

        if (amount > 0) {
            if (!IERC20(pool.lpToken).transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        }
        _payReward(msg.sender, pending);
        emit Deposit(msg.sender, pid, amount);
    }

    function withdraw(uint256 pid, uint256 amount) external {
        updatePool(pid);
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage u = userInfo[pid][msg.sender];
        if (amount > u.amount) revert InsufficientBalance();

        uint256 pending = (u.amount * pool.accRewardPerShare) / ACC_PRECISION - u.rewardDebt;
        u.amount -= amount;
        pool.totalStaked -= amount;
        u.rewardDebt = (u.amount * pool.accRewardPerShare) / ACC_PRECISION;

        if (amount > 0) {
            if (!IERC20(pool.lpToken).transfer(msg.sender, amount)) revert TransferFailed();
        }
        _payReward(msg.sender, pending);
        emit Withdraw(msg.sender, pid, amount);
    }

    function emergencyWithdraw(uint256 pid) external {
        // The pool is updated first so that the leaving stake still counts for the elapsed time
        // and remaining stakers are not credited with more than their share.
        updatePool(pid);
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage u = userInfo[pid][msg.sender];
        uint256 amount = u.amount;
        u.amount = 0;
        u.rewardDebt = 0;
        pool.totalStaked -= amount;
        if (amount > 0) {
            if (!IERC20(pool.lpToken).transfer(msg.sender, amount)) revert TransferFailed();
        }
        emit EmergencyWithdraw(msg.sender, pid, amount);
    }
}
