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
        PendingDeposit memory p = pendingDeposits[user];
        uint256 balance = shares[user];
        if (p.amount != 0 && p.epoch < epoch) {
            balance += (p.amount * WAD) / pricePerShare[p.epoch];
        }
        return balance;
    }

    // ------------------------------------------------------------ deposits

    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        _redeem(msg.sender);
        PendingDeposit storage p = pendingDeposits[msg.sender];
        p.amount += amount;
        p.epoch = epoch;
        totalPending += amount;
        if (!asset.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        emit Deposited(msg.sender, amount, epoch);
    }

    function cancelDeposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        PendingDeposit storage p = pendingDeposits[msg.sender];
        if (p.epoch != epoch || amount > p.amount) revert InsufficientPending();
        p.amount -= amount;
        totalPending -= amount;
        if (!asset.transfer(msg.sender, amount)) revert TransferFailed();
    }

    function redeem() external {
        _redeem(msg.sender);
    }

    // ------------------------------------------------------------ withdrawals

    function requestWithdraw(uint256 shareAmount) external {
        if (shareAmount == 0) revert ZeroAmount();
        _redeem(msg.sender);
        Withdrawal storage w = withdrawals[msg.sender];
        if (w.shares != 0 && w.epoch < epoch) revert WithdrawalNotClaimed();
        if (shareAmount > shares[msg.sender]) revert InsufficientShares();
        shares[msg.sender] -= shareAmount;
        w.shares += shareAmount;
        w.epoch = epoch;
        queuedShares += shareAmount;
        emit WithdrawRequested(msg.sender, shareAmount, epoch);
    }

    function completeWithdraw() external returns (uint256 assets) {
        Withdrawal memory w = withdrawals[msg.sender];
        if (w.shares == 0) revert NoWithdrawal();
        if (w.epoch >= epoch) revert WithdrawalNotReady();
        assets = (w.shares * pricePerShare[w.epoch]) / WAD;
        delete withdrawals[msg.sender];
        withdrawalReserve -= assets;
        if (!asset.transfer(msg.sender, assets)) revert TransferFailed();
        emit WithdrawCompleted(msg.sender, assets);
    }

    // ------------------------------------------------------------ keeper

    function roll(uint256 premium, uint256 payout) external {
        if (msg.sender != owner) revert NotOwner();
        uint256 supply = totalShares;
        uint256 endAssets = lockedAssets;
        uint256 pps = WAD;
        if (supply == 0) {
            if (premium != 0 || payout != 0) revert NothingAtRisk();
        } else {
            if (payout >= endAssets + premium) revert PayoutTooLarge();
            endAssets = endAssets + premium - payout;
            pps = (endAssets * WAD) / supply;
            if (pps == 0) revert PayoutTooLarge();
        }

        // Queued shares took the epoch's result and leave at the settled price; pending
        // deposits enter at the same price and so get none of this epoch's premium or loss.
        uint256 withdrawn = (queuedShares * pps) / WAD;
        uint256 minted = (totalPending * WAD) / pps;

        pricePerShare[epoch] = pps;
        totalShares = supply - queuedShares + minted;
        withdrawalReserve += withdrawn;
        lockedAssets = endAssets - withdrawn + totalPending;
        queuedShares = 0;
        totalPending = 0;
        emit Rolled(epoch, pps, minted, withdrawn);
        epoch += 1;

        if (premium != 0 && !asset.transferFrom(msg.sender, address(this), premium)) revert TransferFailed();
        if (payout != 0 && !asset.transfer(msg.sender, payout)) revert TransferFailed();
    }

    function _redeem(address user) internal {
        PendingDeposit storage p = pendingDeposits[user];
        if (p.amount == 0 || p.epoch >= epoch) return;
        shares[user] += (p.amount * WAD) / pricePerShare[p.epoch];
        p.amount = 0;
    }
}
