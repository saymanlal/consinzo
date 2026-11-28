// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface ICollateral {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title Single-collateral CDP engine. The engine is also the ledger of the stablecoin.
contract CdpEngine {
    struct Vault {
        uint256 collateral; // collateral tokens locked
        uint256 normalizedDebt; // debt divided by the rate at draw time
    }

    error NotOwner();
    error ZeroAmount();
    error UnsafeVault();
    error VaultIsSafe();
    error DebtCeilingExceeded();
    error InsufficientCollateral();
    error InsufficientBalance();
    error BadDebtOutstanding();
    error TransferFailed();

    event Dripped(uint256 rate, uint256 fee);
    event Liquidated(address indexed owner, address indexed liquidator, uint256 repaid, uint256 seized, uint256 badDebt);

    uint256 public constant WAD = 1e18;
    uint256 public constant RAY = 1e27;

    address public immutable owner;
    ICollateral public immutable collateralToken;
    uint256 public immutable liquidationRatio; // WAD, e.g. 1.5e18
    uint256 public immutable liquidationPenalty; // WAD, e.g. 1.1e18
    uint256 public immutable debtCeiling; // stablecoin units

    uint256 public price; // WAD stablecoin per one whole collateral token
    uint256 public ratePerSecond; // RAY, simple rate applied per second between drips
    uint256 public rate = RAY; // accumulator
    uint256 public lastDrip;

    uint256 public totalNormalizedDebt;
    uint256 public badDebt;
    mapping(address => Vault) public vaults;

    // stablecoin ledger
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(
        ICollateral collateralToken_,
        uint256 price_,
        uint256 liquidationRatio_,
        uint256 liquidationPenalty_,
        uint256 ratePerSecond_,
        uint256 debtCeiling_
    ) {
        owner = msg.sender;
        collateralToken = collateralToken_;
        price = price_;
        liquidationRatio = liquidationRatio_;
        liquidationPenalty = liquidationPenalty_;
        ratePerSecond = ratePerSecond_;
        debtCeiling = debtCeiling_;
        lastDrip = block.timestamp;
    }

    // ------------------------------------------------------------ admin

    function setPrice(uint256 newPrice) external {
        // TODO: owner only; store the new price.
        revert("NOT_IMPLEMENTED");
    }

    function setRatePerSecond(uint256 newRatePerSecond) external {
        // TODO: owner only; drip first so the old rate applies up to now, then store the new one.
        revert("NOT_IMPLEMENTED");
    }

    function withdrawSurplus(address to, uint256 amount) external {
        // TODO: owner only; revert BadDebtOutstanding while badDebt > 0; move stablecoin from
        //       the engine's own balance to `to` (InsufficientBalance if it does not have enough).
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------ rate

    function currentRate() public view returns (uint256) {
        // TODO: rate + rate * ratePerSecond * elapsed / RAY (rounded down).
        revert("NOT_IMPLEMENTED");
    }

    function drip() public returns (uint256) {
        // TODO: if time has passed: move rate to currentRate(), mint the fee
        //       totalNormalizedDebt * (newRate - oldRate) / RAY to address(this), update
        //       lastDrip, emit Dripped. Return the stored rate.
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------ views

    function surplus() external view returns (uint256) {
        // TODO: the engine's own stablecoin balance.
        revert("NOT_IMPLEMENTED");
    }

    function debtOf(address user) public view returns (uint256) {
        // TODO: normalizedDebt * currentRate() / RAY, rounded up.
        revert("NOT_IMPLEMENTED");
    }

    function totalDebt() public view returns (uint256) {
        // TODO: totalNormalizedDebt * currentRate() / RAY, rounded up.
        revert("NOT_IMPLEMENTED");
    }

    function isSafe(address user) public view returns (bool) {
        // TODO: collateral * price >= debtOf(user) * liquidationRatio.
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------ vault owner actions

    function deposit(uint256 amount) external {
        // TODO: ZeroAmount check, pull collateral from the caller, credit the vault.
        revert("NOT_IMPLEMENTED");
    }

    function withdraw(uint256 amount) external {
        // TODO: ZeroAmount / InsufficientCollateral checks, debit the vault, require the vault
        //       to be safe afterwards (UnsafeVault), send the collateral.
        revert("NOT_IMPLEMENTED");
    }

    function mint(uint256 amount) external {
        // TODO: drip; add ceil(amount * RAY / rate) normalized debt; require the vault to be
        //       safe (UnsafeVault) and totalDebt() <= debtCeiling (DebtCeilingExceeded);
        //       credit `amount` stablecoin to the caller.
        revert("NOT_IMPLEMENTED");
    }

    function repay(uint256 amount) external returns (uint256 paid) {
        // TODO: drip; cap the payment at debtOf(caller). A capped payment clears all normalized
        //       debt, otherwise remove floor(paid * RAY / rate). Burn `paid` from the caller.
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------ liquidation

    function liquidate(address user, uint256 repayAmount) external returns (uint256 repaid, uint256 seized) {
        // TODO: drip; require the vault to be unsafe (VaultIsSafe otherwise).
        //       repaid = min(repayAmount, debt); seized = repaid * liquidationPenalty / price.
        //       If seized exceeds the collateral: seized = collateral and
        //       repaid = ceil(collateral * price / liquidationPenalty).
        //       Reduce the debt like repay does, burn `repaid` from the liquidator, and if the
        //       vault now has no collateral write the remaining debt off into badDebt.
        //       Send the seized collateral and emit Liquidated.
        revert("NOT_IMPLEMENTED");
    }

    function heal() external returns (uint256 healed) {
        // TODO: burn min(surplus, badDebt) from the engine's balance and reduce badDebt by it.
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------ stablecoin

    function transfer(address to, uint256 amount) external returns (bool) {
        // TODO: move stablecoin from the caller to `to` (InsufficientBalance if short).
        revert("NOT_IMPLEMENTED");
    }

}
