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
        return (collateralAmount * price) / WAD;
    }

    function borrowLimit(uint256 collateralAmount) public view returns (uint256) {
        return (collateralValue(collateralAmount) * ltvBps) / BPS;
    }

    function maxBorrow(address user) public view returns (uint256) {
        return borrowLimit(collateralOf[user]);
    }

    function availableToBorrow(address user) external view returns (uint256) {
        uint256 limit = maxBorrow(user);
        uint256 debt = debtOf[user];
        return limit > debt ? limit - debt : 0;
    }

    function depositCollateral(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        collateralOf[msg.sender] += amount;
        totalCollateral += amount;
        if (!collateralToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        emit CollateralDeposited(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        uint256 newDebt = debtOf[msg.sender] + amount;
        if (newDebt > maxBorrow(msg.sender)) revert ExceedsBorrowLimit();
        if (debtToken.balanceOf(address(this)) < amount) revert InsufficientLiquidity();
        debtOf[msg.sender] = newDebt;
        totalDebt += amount;
        if (!debtToken.transfer(msg.sender, amount)) revert TransferFailed();
        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external returns (uint256 paid) {
        if (amount == 0) revert ZeroAmount();
        uint256 debt = debtOf[msg.sender];
        if (debt == 0) revert NoDebt();
        paid = amount > debt ? debt : amount;
        debtOf[msg.sender] = debt - paid;
        totalDebt -= paid;
        if (!debtToken.transferFrom(msg.sender, address(this), paid)) revert TransferFailed();
        emit Repaid(msg.sender, paid);
    }

    function withdrawCollateral(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        uint256 collateral = collateralOf[msg.sender];
        if (amount > collateral) revert InsufficientCollateral();
        uint256 remaining = collateral - amount;
        // The same rule as in borrow(): the debt must fit under the limit of what stays locked.
        if (debtOf[msg.sender] > borrowLimit(remaining)) revert ExceedsBorrowLimit();
        collateralOf[msg.sender] = remaining;
        totalCollateral -= amount;
        if (!collateralToken.transfer(msg.sender, amount)) revert TransferFailed();
        emit CollateralWithdrawn(msg.sender, amount);
    }
}
