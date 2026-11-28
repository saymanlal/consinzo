// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IAsset {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title Epoch-based options vault. The owner is the keeper and the option counterparty.
contract EpochVault {
    struct PendingDeposit {
        uint256 amount; // assets waiting to be turned into shares
        uint256 epoch; // epoch in which they were deposited
    }

    struct Withdrawal {
        uint256 shares; // shares queued for withdrawal
        uint256 epoch; // epoch in which the request was made
    }

    error NotOwner();
    error ZeroAmount();
    error InsufficientShares();
    error InsufficientPending();
    error WithdrawalNotClaimed();
    error WithdrawalNotReady();
    error NoWithdrawal();
    error PayoutTooLarge();
    error NothingAtRisk();
    error TransferFailed();

    event Deposited(address indexed user, uint256 amount, uint256 epoch);
    event WithdrawRequested(address indexed user, uint256 shares, uint256 epoch);
    event WithdrawCompleted(address indexed user, uint256 assets);
    event Rolled(uint256 indexed epoch, uint256 pricePerShare, uint256 mintedShares, uint256 withdrawnAssets);

    uint256 public constant WAD = 1e18;

    address public immutable owner;
    IAsset public immutable asset;

    uint256 public epoch = 1;
    uint256 public totalShares;
    uint256 public lockedAssets; // assets at risk in the running epoch
    uint256 public totalPending; // deposits waiting for the next roll
    uint256 public queuedShares; // shares waiting to be withdrawn at the next roll
    uint256 public withdrawalReserve; // assets set aside for completed epochs' withdrawals

    mapping(uint256 => uint256) public pricePerShare; // epoch => WAD price fixed at its roll
    mapping(address => uint256) public shares; // redeemed shares
    mapping(address => PendingDeposit) public pendingDeposits;
    mapping(address => Withdrawal) public withdrawals;

    constructor(IAsset asset_) {
        owner = msg.sender;
        asset = asset_;
    }

    // ------------------------------------------------------------ views

    function shareBalanceOf(address user) public view returns (uint256) {
        // TODO: redeemed shares plus the shares of a pending deposit whose epoch has rolled
        //       (amount * WAD / pricePerShare[depositEpoch], rounded down).
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------ deposits

    function deposit(uint256 amount) external {
        // TODO: ZeroAmount; redeem an older pending deposit first; add to the caller's pending
        //       deposit for the current epoch and to totalPending; pull the assets.
        revert("NOT_IMPLEMENTED");
    }

    function cancelDeposit(uint256 amount) external {
        // TODO: ZeroAmount; only assets deposited in the current epoch can be taken back
        //       (InsufficientPending otherwise); return them.
        revert("NOT_IMPLEMENTED");
    }

    function redeem() external {
        // TODO: turn the caller's rolled pending deposit into shares (no-op if there is none).
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------ withdrawals

    function requestWithdraw(uint256 shareAmount) external {
        // TODO: ZeroAmount; redeem first; WithdrawalNotClaimed if a request from an earlier
        //       epoch is still unclaimed; InsufficientShares; move the shares into the queue.
        revert("NOT_IMPLEMENTED");
    }

    function completeWithdraw() external returns (uint256 assets) {
        // TODO: NoWithdrawal / WithdrawalNotReady; pay shares * pricePerShare[requestEpoch] / WAD
        //       (rounded down) out of the withdrawal reserve and clear the request.
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------ keeper

    function roll(uint256 premium, uint256 payout) external {
        // TODO: owner only. Settle the running epoch (see README, "Roll"): fix the price per
        //       share, reserve assets for queued withdrawals, mint shares for pending deposits,
        //       start the next epoch, then pull the premium from and send the payout to the owner.
        revert("NOT_IMPLEMENTED");
    }
}
