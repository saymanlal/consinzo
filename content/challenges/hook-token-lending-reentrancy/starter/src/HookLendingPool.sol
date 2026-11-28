// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20Like {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @notice Single-market lending pool. Users post `collateralToken` and borrow `debtToken`
/// up to 50% of their collateral (both tokens are valued 1:1).
/// @dev The collateral token notifies recipients on transfer (ERC-777 style hook).
contract HookLendingPool {
    error ZeroAmount();
    error InsufficientCollateral();
    error Unhealthy();
    error RepayExceedsDebt();
    error TransferFailed();

    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);

    uint256 public constant LTV_BPS = 5_000;
    uint256 internal constant BPS = 10_000;

    IERC20Like public immutable collateralToken;
    IERC20Like public immutable debtToken;

    mapping(address => uint256) public collateralOf;
    mapping(address => uint256) public debtOf;
    uint256 public totalCollateral;

    constructor(IERC20Like _collateralToken, IERC20Like _debtToken) {
        collateralToken = _collateralToken;
        debtToken = _debtToken;
    }

    /// @notice Largest debt a position with `collateral` may carry.
    function maxDebtFor(uint256 collateral) public pure returns (uint256) {
        return (collateral * LTV_BPS) / BPS;
    }

    function depositCollateral(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (!collateralToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        collateralOf[msg.sender] += amount;
        totalCollateral += amount;
        emit CollateralDeposited(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        uint256 newDebt = debtOf[msg.sender] + amount;
        if (newDebt > maxDebtFor(collateralOf[msg.sender])) revert Unhealthy();
        debtOf[msg.sender] = newDebt;
        if (!debtToken.transfer(msg.sender, amount)) revert TransferFailed();
        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (amount > debtOf[msg.sender]) revert RepayExceedsDebt();
        debtOf[msg.sender] -= amount;
        if (!debtToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        emit Repaid(msg.sender, amount);
    }

    function withdrawCollateral(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        uint256 balance = collateralOf[msg.sender];
        if (amount > balance) revert InsufficientCollateral();
        uint256 remaining = balance - amount;
        if (debtOf[msg.sender] > maxDebtFor(remaining)) revert Unhealthy();

        // TODO: the collateral token calls the recipient's hook inside transfer().
        if (!collateralToken.transfer(msg.sender, amount)) revert TransferFailed();

        collateralOf[msg.sender] = remaining;
        totalCollateral -= amount;
        emit CollateralWithdrawn(msg.sender, amount);
    }
}
