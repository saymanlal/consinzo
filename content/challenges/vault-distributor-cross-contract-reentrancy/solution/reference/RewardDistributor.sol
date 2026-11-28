// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Pays ETH rewards to stakers of `StakeVault`, pro rata to their stake.
/// @dev Stake balances live in the vault; this contract only stores reward bookkeeping.
/// The vault calls `settle` before and `sync` after every balance change.
contract RewardDistributor {
    error NotVault();
    error NothingStaked();
    error Reentrancy();
    error TransferFailed();

    event Funded(address indexed from, uint256 amount);
    event RewardPaid(address indexed user, uint256 amount);

    uint256 internal constant PRECISION = 1e18;

    StakeVault public immutable vault;
    /// @notice Cumulative reward per staked wei, scaled by 1e18.
    uint256 public accRewardPerShare;
    /// @notice Reward already accounted for at the user's current stake.
    mapping(address => uint256) public rewardDebt;

    uint256 private _lock = 1;

    modifier nonReentrant() {
        if (_lock != 1) revert Reentrancy();
        _lock = 2;
        _;
        _lock = 1;
    }

    modifier onlyVault() {
        if (msg.sender != address(vault)) revert NotVault();
        _;
    }

    constructor() {
        vault = StakeVault(msg.sender);
    }

    /// @notice Add rewards, shared by everyone staked right now.
    function fund() external payable {
        uint256 total = vault.totalStaked();
        if (total == 0) revert NothingStaked();
        accRewardPerShare += (msg.value * PRECISION) / total;
        emit Funded(msg.sender, msg.value);
    }

    function pending(address user) public view returns (uint256) {
        return (vault.balanceOf(user) * accRewardPerShare) / PRECISION - rewardDebt[user];
    }

    /// @notice Claim the caller's accrued rewards.
    function claim() external nonReentrant {
        _harvest(msg.sender);
    }

    /// @notice Vault hook: pay out what `user` earned on the stake they held so far.
    /// The vault changes the balance next and then calls `sync`.
    function settle(address user) external onlyVault {
        _harvest(user);
    }

    /// @dev Single payout path for both entry points. The debt is brought up to date
    /// BEFORE the ETH leaves, so while the recipient's code runs `pending(user)` is zero.
    /// A nested call cannot be paid again, whether it comes directly (`claim`) or through
    /// the vault (`settle`), and regardless of which contract's lock happens to be open.
    function _harvest(address user) internal {
        uint256 amount = pending(user);
        rewardDebt[user] = (vault.balanceOf(user) * accRewardPerShare) / PRECISION;
        _pay(user, amount);
    }

    /// @notice Vault hook: restart accounting at the user's new stake.
    function sync(address user) external onlyVault {
        rewardDebt[user] = (vault.balanceOf(user) * accRewardPerShare) / PRECISION;
    }

    function _pay(address user, uint256 amount) internal {
        if (amount == 0) return;
        (bool ok, ) = user.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit RewardPaid(user, amount);
    }
}

/// @notice ETH staking vault. Deploys its own distributor.
contract StakeVault {
    error ZeroAmount();
    error InsufficientStake();
    error Reentrancy();
    error TransferFailed();

    RewardDistributor public immutable distributor;
    mapping(address => uint256) public balanceOf;
    uint256 public totalStaked;

    uint256 private _lock = 1;

    modifier nonReentrant() {
        if (_lock != 1) revert Reentrancy();
        _lock = 2;
        _;
        _lock = 1;
    }

    constructor() {
        distributor = new RewardDistributor();
    }

    function deposit() external payable nonReentrant {
        if (msg.value == 0) revert ZeroAmount();
        distributor.settle(msg.sender);
        balanceOf[msg.sender] += msg.value;
        totalStaked += msg.value;
        distributor.sync(msg.sender);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount > balanceOf[msg.sender]) revert InsufficientStake();
        distributor.settle(msg.sender);
        balanceOf[msg.sender] -= amount;
        totalStaked -= amount;
        distributor.sync(msg.sender);
        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}
