// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract CollateralLender {
    error ZeroAmount();
    error ExceedsBorrowLimit();
    error InsufficientLiquidity();
    error InsufficientCollateral();
    error NoDebt();
    error TransferFailed();

    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);

    uint256 internal constant WAD = 1e18;
    uint256 internal constant BPS = 10_000;

    IERC20 public immutable collateralToken;
    IERC20 public immutable debtToken;
    /// @notice Value of 1e18 collateral base units, in debt-token base units.
    uint256 public immutable price;
    /// @notice Maximum loan-to-value in basis points.
    uint256 public immutable ltvBps;

    mapping(address => uint256) public collateralOf;
    mapping(address => uint256) public debtOf;
    uint256 public totalCollateral;
    uint256 public totalDebt;

    constructor(address collateralToken_, address debtToken_, uint256 price_, uint256 ltvBps_) {
        collateralToken = IERC20(collateralToken_);
        debtToken = IERC20(debtToken_);
        price = price_;
        ltvBps = ltvBps_;
    }

    function collateralValue(uint256 collateralAmount) public view returns (uint256) {
        // TODO: collateralAmount * price / 1e18
        revert("NOT_IMPLEMENTED");
    }

    function borrowLimit(uint256 collateralAmount) public view returns (uint256) {
        // TODO: collateralValue(collateralAmount) * ltvBps / 10_000
        revert("NOT_IMPLEMENTED");
    }

    function maxBorrow(address user) public view returns (uint256) {
        // TODO: Borrow limit of the user's current collateral.
        revert("NOT_IMPLEMENTED");
    }

    function availableToBorrow(address user) external view returns (uint256) {
        // TODO: maxBorrow minus current debt, floored at zero.
        revert("NOT_IMPLEMENTED");
    }

    function depositCollateral(uint256 amount) external {
        // TODO: Validate, record, pull collateral, emit CollateralDeposited.
        revert("NOT_IMPLEMENTED");
    }

    function borrow(uint256 amount) external {
        // TODO: Checks in order: ZeroAmount, ExceedsBorrowLimit, InsufficientLiquidity.
        //       Record the debt, send debt tokens, emit Borrowed.
        revert("NOT_IMPLEMENTED");
    }

    function repay(uint256 amount) external returns (uint256 paid) {
        // TODO: Validate, cap the payment at the caller's debt, pull tokens, emit Repaid.
        revert("NOT_IMPLEMENTED");
    }

    function withdrawCollateral(uint256 amount) external {
        // TODO: Checks in order: ZeroAmount, InsufficientCollateral, ExceedsBorrowLimit
        //       (evaluated on the collateral that would remain). Send collateral, emit CollateralWithdrawn.
        revert("NOT_IMPLEMENTED");
    }
}
