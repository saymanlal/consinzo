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
        if (msg.sender != owner) revert NotOwner();
        price = newPrice;
    }

    // ------------------------------------------------------------------ interest

    function accrue() public {
        uint256 elapsed = block.timestamp - lastAccrual;
        if (elapsed == 0) return;
        lastAccrual = block.timestamp;
        // Simple interest per accrual step. Borrowers owe it and suppliers earn it, so both
        // totals move together and no share balance changes.
        uint256 interest = (totalBorrowAssets * ratePerSecond * elapsed) / WAD;
        totalBorrowAssets += interest;
        totalSupplyAssets += interest;
    }

    // ------------------------------------------------------------------ supply side

    function supply(uint256 assets) external returns (uint256 shares) {
        accrue();
        if (assets == 0) revert ZeroAmount();
        shares = _mulDivDown(assets, totalSupplyShares + 1, totalSupplyAssets + 1);
        if (shares == 0) revert ZeroAmount();
        totalSupplyAssets += assets;
        totalSupplyShares += shares;
        supplyShares[msg.sender] += shares;
        _pull(asset, assets);
        emit Supplied(msg.sender, assets, shares);
    }

    function withdraw(uint256 shares) external returns (uint256 assets) {
        accrue();
        if (shares == 0) revert ZeroAmount();
        if (shares > supplyShares[msg.sender]) revert InsufficientShares();
        assets = _mulDivDown(shares, totalSupplyAssets + 1, totalSupplyShares + 1);
        // Cash is whatever is supplied and not lent out.
        if (assets > totalSupplyAssets - totalBorrowAssets) revert InsufficientLiquidity();
        supplyShares[msg.sender] -= shares;
        totalSupplyShares -= shares;
        totalSupplyAssets -= assets;
        _push(asset, assets);
        emit Withdrawn(msg.sender, assets, shares);
    }

    // ------------------------------------------------------------------ collateral

    function depositCollateral(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        collateralOf[msg.sender] += amount;
        _pull(collateral, amount);
    }

    function withdrawCollateral(uint256 amount) external {
        accrue();
        if (amount == 0) revert ZeroAmount();
        if (amount > collateralOf[msg.sender]) revert InsufficientCollateral();
        collateralOf[msg.sender] -= amount;
        if (!_healthy(msg.sender)) revert PositionUnhealthy();
        _push(collateral, amount);
    }

    // ------------------------------------------------------------------ borrow side

    function borrow(uint256 assets) external returns (uint256 shares) {
        accrue();
        if (assets == 0) revert ZeroAmount();
        if (assets > totalSupplyAssets - totalBorrowAssets) revert InsufficientLiquidity();
        shares = _mulDivUp(assets, totalBorrowShares + 1, totalBorrowAssets + 1);
        totalBorrowAssets += assets;
        totalBorrowShares += shares;
        borrowShares[msg.sender] += shares;
        if (!_healthy(msg.sender)) revert PositionUnhealthy();
        _push(asset, assets);
        emit Borrowed(msg.sender, assets, shares);
    }

    function repay(address borrower, uint256 shares) external returns (uint256 assets) {
        accrue();
        if (shares == 0) revert ZeroAmount();
        if (shares > borrowShares[borrower]) revert RepayExceedsDebt();
        assets = _mulDivUp(shares, totalBorrowAssets + 1, totalBorrowShares + 1);
        borrowShares[borrower] -= shares;
        totalBorrowShares -= shares;
        // Rounding up can exceed the tracked total by a wei on the last repayment.
        totalBorrowAssets -= _min(assets, totalBorrowAssets);
        _pull(asset, assets);
        emit Repaid(msg.sender, borrower, assets, shares);
    }

    // ------------------------------------------------------------------ liquidation

    function liquidate(address borrower, uint256 seizeCollateral) external returns (uint256 repaidAssets) {
        accrue();
        if (seizeCollateral == 0) revert ZeroAmount();
        if (_healthy(borrower)) revert PositionHealthy();
        if (seizeCollateral > collateralOf[borrower]) revert InsufficientCollateral();

        // The liquidator pays the oracle value of the seized collateral divided by the bonus.
        repaidAssets = _mulDivUp(_mulDivUp(seizeCollateral, price, WAD), WAD, liquidationBonus);
        uint256 repaidShares = _mulDivDown(repaidAssets, totalBorrowShares + 1, totalBorrowAssets + 1);
        if (repaidShares > borrowShares[borrower]) revert RepayExceedsDebt();

        borrowShares[borrower] -= repaidShares;
        totalBorrowShares -= repaidShares;
        totalBorrowAssets -= _min(repaidAssets, totalBorrowAssets);
        collateralOf[borrower] -= seizeCollateral;

        // No collateral left: the remaining debt can never be recovered. Write it off against
        // suppliers by shrinking both asset totals.
        uint256 leftover = borrowShares[borrower];
        if (collateralOf[borrower] == 0 && leftover > 0) {
            uint256 bad = _min(_mulDivUp(leftover, totalBorrowAssets + 1, totalBorrowShares + 1), totalBorrowAssets);
            totalBorrowAssets -= bad;
            totalSupplyAssets -= bad;
            totalBorrowShares -= leftover;
            borrowShares[borrower] = 0;
            emit BadDebtRealised(borrower, bad, leftover);
        }

        _pull(asset, repaidAssets);
        _push(collateral, seizeCollateral);
        emit Liquidated(msg.sender, borrower, seizeCollateral, repaidAssets);
    }

    // ------------------------------------------------------------------ views

    /// @notice Debt of `user` in assets, rounded up, using the totals as last accrued.
    function debtOf(address user) public view returns (uint256) {
        return _mulDivUp(borrowShares[user], totalBorrowAssets + 1, totalBorrowShares + 1);
    }

    function isHealthy(address user) external view returns (bool) {
        return _healthy(user);
    }

    // ------------------------------------------------------------------ internals

    function _healthy(address user) internal view returns (bool) {
        if (borrowShares[user] == 0) return true;
        uint256 maxBorrow = _mulDivDown(_mulDivDown(collateralOf[user], price, WAD), lltv, WAD);
        return debtOf(user) <= maxBorrow;
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
