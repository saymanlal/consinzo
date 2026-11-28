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
    error Reentrancy();

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

    uint256 private _lock = 1;

    /// @dev One lock shared by every state-changing function. A hook fired by one of them
    /// cannot enter any of the others (cross-function reentrancy).
    modifier nonReentrant() {
        if (_lock != 1) revert Reentrancy();
        _lock = 2;
        _;
        _lock = 1;
    }

    constructor(IERC20Like _collateralToken, IERC20Like _debtToken) {
        collateralToken = _collateralToken;
        debtToken = _debtToken;
    }

    /// @notice Largest debt a position with `collateral` may carry.
    function maxDebtFor(uint256 collateral) public pure returns (uint256) {
        return (collateral * LTV_BPS) / BPS;
    }

    function depositCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        // Crediting after the pull is the safe order here: a hook on the sending side must
        // not be able to borrow against collateral the pool has not received yet. The lock
        // keeps that hook out of the other entry points.
        if (!collateralToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        collateralOf[msg.sender] += amount;
        totalCollateral += amount;
        emit CollateralDeposited(msg.sender, amount);
    }

    function borrow(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 newDebt = debtOf[msg.sender] + amount;
        if (newDebt > maxDebtFor(collateralOf[msg.sender])) revert Unhealthy();
        debtOf[msg.sender] = newDebt;
        if (!debtToken.transfer(msg.sender, amount)) revert TransferFailed();
        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount > debtOf[msg.sender]) revert RepayExceedsDebt();
        debtOf[msg.sender] -= amount;
        if (!debtToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        emit Repaid(msg.sender, amount);
    }

    function withdrawCollateral(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 balance = collateralOf[msg.sender];
        if (amount > balance) revert InsufficientCollateral();
        uint256 remaining = balance - amount;
        if (debtOf[msg.sender] > maxDebtFor(remaining)) revert Unhealthy();

        // Effects before the interaction: when the token's hook runs, storage already
        // shows the reduced position, so nothing the recipient calls can use the old one.
        collateralOf[msg.sender] = remaining;
        totalCollateral -= amount;

        if (!collateralToken.transfer(msg.sender, amount)) revert TransferFailed();
        emit CollateralWithdrawn(msg.sender, amount);
    }
}
