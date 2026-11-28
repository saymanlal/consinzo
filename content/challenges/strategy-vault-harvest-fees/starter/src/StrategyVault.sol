// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IAsset {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IStrategy {
    /// Sends up to `amount` of the asset back to the vault and returns what it claims to have sent.
    function withdraw(uint256 amount) external returns (uint256);

    /// Current value of the strategy's position in asset units.
    function totalAssets() external view returns (uint256);
}

/// @title Share-based vault with one strategy, harvest accounting and fee shares.
contract StrategyVault {
    error NotOwner();
    error ZeroAmount();
    error ZeroShares();
    error FeeTooHigh();
    error InsufficientShares();
    error InsufficientIdle();
    error InsufficientDebt();
    error LossTooHigh();
    error TransferFailed();

    event Deposit(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, uint256 assets, uint256 shares, uint256 loss);
    event Harvest(uint256 profit, uint256 loss, uint256 feeShares);

    uint256 public constant BPS = 10_000;
    uint256 public constant MAX_PERFORMANCE_FEE_BPS = 5_000;

    address public immutable owner;
    IAsset public immutable asset;
    IStrategy public immutable strategy;
    address public immutable feeRecipient;
    uint256 public immutable performanceFeeBps;

    uint256 public idleAssets; // assets held by the vault and owned by shareholders
    uint256 public strategyDebt; // assets deployed, as of the last report
    uint256 public unrecoveredLoss; // harvest losses not yet offset by later profit

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(IAsset asset_, IStrategy strategy_, address feeRecipient_, uint256 performanceFeeBps_) {
        if (performanceFeeBps_ > MAX_PERFORMANCE_FEE_BPS) revert FeeTooHigh();
        owner = msg.sender;
        asset = asset_;
        strategy = strategy_;
        feeRecipient = feeRecipient_;
        performanceFeeBps = performanceFeeBps_;
    }

    // ------------------------------------------------------------ views

    function totalAssets() public view returns (uint256) {
        // TODO: idleAssets + strategyDebt (never a token balance).
        revert("NOT_IMPLEMENTED");
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        // TODO: 1:1 while there are no shares, otherwise assets * totalSupply / totalAssets, rounded down.
        revert("NOT_IMPLEMENTED");
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        // TODO: 1:1 while there are no shares, otherwise shares * totalAssets / totalSupply, rounded down.
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------ users

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        // TODO: ZeroAmount; shares = convertToShares(assets), ZeroShares if 0; mint to receiver,
        //       add to idleAssets, pull the assets, emit Deposit.
        revert("NOT_IMPLEMENTED");
    }

    function withdraw(uint256 shares, address receiver, uint256 maxLossBps) external returns (uint256 assets) {
        // TODO: ZeroAmount / InsufficientShares; value the shares, burn them.
        //       If idle assets do not cover the value, pull the missing amount from the strategy
        //       (measure what actually arrives), reduce strategyDebt by the amount requested and
        //       charge any shortfall to this withdrawal; LossTooHigh if
        //       loss * BPS > value * maxLossBps. Pay out and emit Withdraw.
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------ owner / keeper

    function invest(uint256 amount) external {
        // TODO: owner only; InsufficientIdle; move idle assets to the strategy and add to strategyDebt.
        revert("NOT_IMPLEMENTED");
    }

    function divest(uint256 amount) external returns (uint256 received) {
        // TODO: owner only; InsufficientDebt; pull `amount` from the strategy, measuring what
        //       arrives; strategyDebt -= amount, idleAssets += received; a shortfall is added
        //       to unrecoveredLoss.
        revert("NOT_IMPLEMENTED");
    }

    function harvest() external returns (uint256 profit, uint256 loss, uint256 feeShares) {
        // TODO: owner only. Compare strategy.totalAssets() with strategyDebt and set the debt to
        //       the reported value.
        //       Profit: first reduce unrecoveredLoss; the fee is performanceFeeBps of the rest
        //       and is paid by minting fee * supply / (totalAssets - fee) shares to feeRecipient.
        //       Loss: add it to unrecoveredLoss. Emit Harvest.
        revert("NOT_IMPLEMENTED");
    }
}
