// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title TwinMarket
/// @notice Two share-based lending markets with cross-collateral borrowing. Assets are valued 1:1.
contract TwinMarket {
    uint256 public constant COLLATERAL_FACTOR_BPS = 7500;
    uint256 public constant BORROW_FEE_BPS = 100;
    uint256 private constant BPS = 10_000;

    error InvalidMarket();
    error ZeroAmount();
    error ZeroShares();
    error InsufficientShares();
    error InsufficientCash();
    error Undercollateralized();
    error TransferFailed();

    IERC20[2] public tokens;
    uint256[2] public totalShares;
    uint256[2] public totalBorrows;
    /// @dev Underlying held on behalf of each market, updated only by this contract's own flows.
    uint256[2] private _cash;

    mapping(uint256 => mapping(address => uint256)) public sharesOf;
    mapping(uint256 => mapping(address => uint256)) public debtOf;

    modifier validMarket(uint256 id) {
        if (id > 1) revert InvalidMarket();
        _;
    }

    constructor(address token0, address token1) {
        tokens[0] = IERC20(token0);
        tokens[1] = IERC20(token1);
    }

    // ------------------------------------------------------------------ views

    function cash(uint256 id) public view validMarket(id) returns (uint256) {
        return _cash[id];
    }

    function totalAssets(uint256 id) public view returns (uint256) {
        return cash(id) + totalBorrows[id];
    }

    function exchangeRate(uint256 id) public view returns (uint256) {
        uint256 supply = totalShares[id];
        if (supply == 0) return 1e18;
        return (totalAssets(id) * 1e18) / supply;
    }

    function collateralValue(address account) public view returns (uint256 value) {
        for (uint256 id = 0; id < 2; id++) {
            uint256 supply = totalShares[id];
            if (supply == 0) continue;
            value += (sharesOf[id][account] * totalAssets(id)) / supply;
        }
        value = (value * COLLATERAL_FACTOR_BPS) / BPS;
    }

    function debtValue(address account) public view returns (uint256) {
        return debtOf[0][account] + debtOf[1][account];
    }

    // ---------------------------------------------------------------- supply

    function mint(uint256 id, uint256 amount) external validMarket(id) returns (uint256 sharesMinted) {
        if (amount == 0) revert ZeroAmount();
        uint256 supply = totalShares[id];
        sharesMinted = supply == 0 ? amount : (amount * supply) / totalAssets(id);
        if (sharesMinted == 0) revert ZeroShares();
        totalShares[id] = supply + sharesMinted;
        sharesOf[id][msg.sender] += sharesMinted;
        _pullIn(id, amount);
    }

    function redeem(uint256 id, uint256 shareAmount) external validMarket(id) returns (uint256 amountOut) {
        if (shareAmount == 0) revert ZeroAmount();
        amountOut = (shareAmount * totalAssets(id)) / totalShares[id];
        _redeem(id, shareAmount, amountOut);
    }

    function redeemUnderlying(uint256 id, uint256 amount) external validMarket(id) returns (uint256 sharesBurned) {
        if (amount == 0) revert ZeroAmount();
        uint256 supply = totalShares[id];
        if (supply == 0) revert InsufficientShares();
        // The caller fixes the amount out, so the shares paid for it round up. Rounding
        // down would let small or carefully sized withdrawals cost fewer shares than they
        // are worth, down to zero.
        uint256 assets = totalAssets(id);
        sharesBurned = (amount * supply + assets - 1) / assets;
        _redeem(id, sharesBurned, amount);
    }

    function _redeem(uint256 id, uint256 shareAmount, uint256 amountOut) private {
        if (shareAmount > sharesOf[id][msg.sender]) revert InsufficientShares();
        if (amountOut > cash(id)) revert InsufficientCash();
        sharesOf[id][msg.sender] -= shareAmount;
        totalShares[id] -= shareAmount;
        // Cash leaves the books before the health check, so the check sees the final state.
        _cash[id] -= amountOut;
        _requireHealthy(msg.sender);
        _pushOut(id, amountOut);
    }

    // ---------------------------------------------------------------- borrow

    function borrow(uint256 id, uint256 amount) external validMarket(id) {
        if (amount == 0) revert ZeroAmount();
        if (amount > cash(id)) revert InsufficientCash();
        uint256 owed = amount + (amount * BORROW_FEE_BPS) / BPS;
        debtOf[id][msg.sender] += owed;
        totalBorrows[id] += owed;
        _cash[id] -= amount;
        _requireHealthy(msg.sender);
        _pushOut(id, amount);
    }

    function repay(uint256 id, uint256 amount) external validMarket(id) returns (uint256 repaid) {
        if (amount == 0) revert ZeroAmount();
        uint256 owed = debtOf[id][msg.sender];
        repaid = amount > owed ? owed : amount;
        debtOf[id][msg.sender] = owed - repaid;
        totalBorrows[id] -= repaid;
        _pullIn(id, repaid);
    }

    // -------------------------------------------------------------- internal

    function _requireHealthy(address account) private view {
        if (debtValue(account) > collateralValue(account)) revert Undercollateralized();
    }

    function _pullIn(uint256 id, uint256 amount) private {
        _cash[id] += amount;
        if (!tokens[id].transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
    }

    function _pushOut(uint256 id, uint256 amount) private {
        if (!tokens[id].transfer(msg.sender, amount)) revert TransferFailed();
    }
}
