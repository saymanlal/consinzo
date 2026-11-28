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
        return idleAssets + strategyDebt;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply;
        return supply == 0 ? assets : (assets * supply) / totalAssets();
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply;
        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }

    // ------------------------------------------------------------ users

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();
        shares = convertToShares(assets);
        if (shares == 0) revert ZeroShares();
        totalSupply += shares;
        balanceOf[receiver] += shares;
        idleAssets += assets;
        if (!asset.transferFrom(msg.sender, address(this), assets)) revert TransferFailed();
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function withdraw(uint256 shares, address receiver, uint256 maxLossBps) external returns (uint256 assets) {
        if (shares == 0) revert ZeroAmount();
        if (shares > balanceOf[msg.sender]) revert InsufficientShares();
        assets = convertToAssets(shares);
        balanceOf[msg.sender] -= shares;
        totalSupply -= shares;

        uint256 loss;
        if (assets > idleAssets) {
            uint256 need = assets - idleAssets;
            uint256 received = _pullFromStrategy(need);
            strategyDebt -= need;
            idleAssets += received;
            if (received < need) {
                // The strategy could not return everything: this withdrawer takes the shortfall,
                // the remaining holders keep their price.
                loss = need - received;
                if (loss * BPS > assets * maxLossBps) revert LossTooHigh();
                assets -= loss;
            }
        }
        idleAssets -= assets;
        if (!asset.transfer(receiver, assets)) revert TransferFailed();
        emit Withdraw(msg.sender, receiver, assets, shares, loss);
    }

    // ------------------------------------------------------------ owner / keeper

    function invest(uint256 amount) external {
        if (msg.sender != owner) revert NotOwner();
        if (amount > idleAssets) revert InsufficientIdle();
        idleAssets -= amount;
        strategyDebt += amount;
        if (!asset.transfer(address(strategy), amount)) revert TransferFailed();
    }

    function divest(uint256 amount) external returns (uint256 received) {
        if (msg.sender != owner) revert NotOwner();
        if (amount > strategyDebt) revert InsufficientDebt();
        received = _pullFromStrategy(amount);
        strategyDebt -= amount;
        idleAssets += received;
        if (received < amount) unrecoveredLoss += amount - received;
    }

    function harvest() external returns (uint256 profit, uint256 loss, uint256 feeShares) {
        if (msg.sender != owner) revert NotOwner();
        uint256 reported = strategy.totalAssets();
        uint256 debt = strategyDebt;
        strategyDebt = reported;
        if (reported > debt) {
            profit = reported - debt;
            uint256 recovered = profit < unrecoveredLoss ? profit : unrecoveredLoss;
            unrecoveredLoss -= recovered;
            uint256 fee = ((profit - recovered) * performanceFeeBps) / BPS;
            uint256 supply = totalSupply;
            if (fee != 0 && supply != 0) {
                // New shares must be worth `fee` after the mint:
                // feeShares / (supply + feeShares) = fee / totalAssets.
                feeShares = (fee * supply) / (totalAssets() - fee);
                totalSupply = supply + feeShares;
                balanceOf[feeRecipient] += feeShares;
            }
        } else if (reported < debt) {
            loss = debt - reported;
            unrecoveredLoss += loss;
        }
        emit Harvest(profit, loss, feeShares);
    }

    /// @dev Never trusts the strategy's return value: counts the tokens that arrived.
    function _pullFromStrategy(uint256 amount) internal returns (uint256 received) {
        uint256 before = asset.balanceOf(address(this));
        strategy.withdraw(amount);
        received = asset.balanceOf(address(this)) - before;
    }
}
