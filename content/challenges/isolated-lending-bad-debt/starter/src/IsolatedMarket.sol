// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title Isolated lending market: one loan asset, one collateral asset, socialised bad debt.
contract IsolatedMarket {
    uint256 internal constant WAD = 1e18;

    error NotOwner();
    error InvalidParameter();
    error ZeroAmount();
    error InsufficientShares();
    error InsufficientCollateral();
    error InsufficientLiquidity();
    error PositionUnhealthy();
    error PositionHealthy();
    error RepayExceedsDebt();
    error TransferFailed();

    event Supplied(address indexed user, uint256 assets, uint256 shares);
    event Withdrawn(address indexed user, uint256 assets, uint256 shares);
    event Borrowed(address indexed user, uint256 assets, uint256 shares);
    event Repaid(address indexed payer, address indexed borrower, uint256 assets, uint256 shares);
    event Liquidated(address indexed liquidator, address indexed borrower, uint256 seized, uint256 repaidAssets);
    event BadDebtRealised(address indexed borrower, uint256 assets, uint256 shares);

    address public immutable owner;
    IERC20 public immutable asset;
    IERC20 public immutable collateral;
    uint256 public immutable lltv; // WAD
    uint256 public immutable ratePerSecond; // WAD
    uint256 public immutable liquidationBonus; // WAD, >= 1e18

    uint256 public price; // asset units per collateral unit, WAD
    uint256 public lastAccrual;

    uint256 public totalSupplyAssets;
    uint256 public totalSupplyShares;
    uint256 public totalBorrowAssets;
    uint256 public totalBorrowShares;

    mapping(address => uint256) public supplyShares;
    mapping(address => uint256) public borrowShares;
    mapping(address => uint256) public collateralOf;

    constructor(address asset_, address collateral_, uint256 lltv_, uint256 ratePerSecond_, uint256 liquidationBonus_) {
        if (lltv_ == 0 || lltv_ >= WAD || liquidationBonus_ < WAD) revert InvalidParameter();
        owner = msg.sender;
        asset = IERC20(asset_);
        collateral = IERC20(collateral_);
        lltv = lltv_;
        ratePerSecond = ratePerSecond_;
        liquidationBonus = liquidationBonus_;
        lastAccrual = block.timestamp;
    }

    // ------------------------------------------------------------------ admin

    function setPrice(uint256 newPrice) external {
        // TODO: owner only; store the new oracle price.
        newPrice;
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------------ interest

    function accrue() public {
        // TODO: interest = totalBorrowAssets * ratePerSecond * elapsed / 1e18 (round down),
        //       added to both asset totals; update lastAccrual.
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------------ supply side

    function supply(uint256 assets) external returns (uint256 shares) {
        // TODO: accrue, mint shares rounded down (virtual +1 on both totals), pull the asset.
        assets;
        revert("NOT_IMPLEMENTED");
    }

    function withdraw(uint256 shares) external returns (uint256 assets) {
        // TODO: accrue, burn shares for assets rounded down, enforce available liquidity.
        shares;
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------------ collateral

    function depositCollateral(uint256 amount) external {
        // TODO: credit collateral and pull the tokens.
        amount;
        revert("NOT_IMPLEMENTED");
    }

    function withdrawCollateral(uint256 amount) external {
        // TODO: accrue, debit collateral, require the position to stay healthy.
        amount;
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------------ borrow side

    function borrow(uint256 assets) external returns (uint256 shares) {
        // TODO: accrue, check liquidity, mint borrow shares rounded up, require health, send assets.
        assets;
        revert("NOT_IMPLEMENTED");
    }

    function repay(address borrower, uint256 shares) external returns (uint256 assets) {
        // TODO: accrue, burn `shares` of `borrower` debt, charge assets rounded up.
        borrower;
        shares;
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------------ liquidation

    function liquidate(address borrower, uint256 seizeCollateral) external returns (uint256 repaidAssets) {
        // TODO: accrue, require an unhealthy position, price the seized collateral with the bonus,
        //       reduce the debt, and write off any debt left once collateral reaches zero.
        borrower;
        seizeCollateral;
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------------ views

    /// @notice Debt of `user` in assets, rounded up, using the totals as last accrued.
    function debtOf(address user) public view returns (uint256) {
        // TODO: borrow shares converted to assets, rounded up.
        user;
        return 0;
    }

    function isHealthy(address user) external view returns (bool) {
        return _healthy(user);
    }

    // ------------------------------------------------------------------ internals

    function _healthy(address user) internal view returns (bool) {
        // TODO: no debt, or debt <= collateral * price * lltv (each division rounds down).
        user;
        return false;
    }

    function _pull(IERC20 token, uint256 amount) internal {
        if (!token.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
    }

    function _push(IERC20 token, uint256 amount) internal {
        if (!token.transfer(msg.sender, amount)) revert TransferFailed();
    }

    function _mulDivDown(uint256 a, uint256 b, uint256 d) internal pure returns (uint256) {
        return (a * b) / d;
    }

    function _mulDivUp(uint256 a, uint256 b, uint256 d) internal pure returns (uint256) {
        return (a * b + d - 1) / d;
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
