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
        if (msg.sender != owner) revert NotOwner();
        price = newPrice;
    }

    function setRatePerSecond(uint256 newRatePerSecond) external {
        if (msg.sender != owner) revert NotOwner();
        drip();
        ratePerSecond = newRatePerSecond;
    }

    function withdrawSurplus(address to, uint256 amount) external {
        if (msg.sender != owner) revert NotOwner();
        if (badDebt != 0) revert BadDebtOutstanding();
        _move(address(this), to, amount);
    }

    // ------------------------------------------------------------ rate

    function currentRate() public view returns (uint256) {
        uint256 elapsed = block.timestamp - lastDrip;
        return rate + (rate * ratePerSecond * elapsed) / RAY;
    }

    function drip() public returns (uint256) {
        if (block.timestamp > lastDrip) {
            uint256 newRate = currentRate();
            uint256 fee = (totalNormalizedDebt * (newRate - rate)) / RAY;
            rate = newRate;
            lastDrip = block.timestamp;
            totalSupply += fee;
            balanceOf[address(this)] += fee;
            emit Dripped(newRate, fee);
        }
        return rate;
    }

    // ------------------------------------------------------------ views

    function surplus() external view returns (uint256) {
        return balanceOf[address(this)];
    }

    function debtOf(address user) public view returns (uint256) {
        return _mulUp(vaults[user].normalizedDebt, currentRate());
    }

    function totalDebt() public view returns (uint256) {
        return _mulUp(totalNormalizedDebt, currentRate());
    }

    function isSafe(address user) public view returns (bool) {
        return vaults[user].collateral * price >= debtOf(user) * liquidationRatio;
    }

    // ------------------------------------------------------------ vault owner actions

    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        vaults[msg.sender].collateral += amount;
        if (!collateralToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        Vault storage v = vaults[msg.sender];
        if (amount > v.collateral) revert InsufficientCollateral();
        v.collateral -= amount;
        if (!isSafe(msg.sender)) revert UnsafeVault();
        if (!collateralToken.transfer(msg.sender, amount)) revert TransferFailed();
    }

    function mint(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        uint256 r = drip();
        uint256 dart = (amount * RAY + r - 1) / r;
        vaults[msg.sender].normalizedDebt += dart;
        totalNormalizedDebt += dart;
        if (!isSafe(msg.sender)) revert UnsafeVault();
        if (totalDebt() > debtCeiling) revert DebtCeilingExceeded();
        totalSupply += amount;
        balanceOf[msg.sender] += amount;
    }

    function repay(uint256 amount) external returns (uint256 paid) {
        if (amount == 0) revert ZeroAmount();
        uint256 r = drip();
        Vault storage v = vaults[msg.sender];
        uint256 debt = _mulUp(v.normalizedDebt, r);
        uint256 dart;
        if (amount >= debt) {
            paid = debt;
            dart = v.normalizedDebt;
        } else {
            paid = amount;
            dart = (amount * RAY) / r;
        }
        v.normalizedDebt -= dart;
        totalNormalizedDebt -= dart;
        _burn(msg.sender, paid);
    }

    // ------------------------------------------------------------ liquidation

    function liquidate(address user, uint256 repayAmount) external returns (uint256 repaid, uint256 seized) {
        if (repayAmount == 0) revert ZeroAmount();
        uint256 r = drip();
        if (isSafe(user)) revert VaultIsSafe();
        Vault storage v = vaults[user];
        uint256 debt = _mulUp(v.normalizedDebt, r);

        repaid = repayAmount > debt ? debt : repayAmount;
        seized = (repaid * liquidationPenalty) / price;
        if (seized > v.collateral) {
            // Not enough collateral for this repayment: the liquidator only pays for what exists.
            seized = v.collateral;
            repaid = (seized * price + liquidationPenalty - 1) / liquidationPenalty;
        }

        uint256 dart = repaid == debt ? v.normalizedDebt : (repaid * RAY) / r;
        v.normalizedDebt -= dart;
        totalNormalizedDebt -= dart;
        v.collateral -= seized;
        _burn(msg.sender, repaid);

        uint256 bad;
        if (v.collateral == 0 && v.normalizedDebt != 0) {
            // Nothing left to seize: the remaining debt can never be recovered from this vault.
            bad = _mulUp(v.normalizedDebt, r);
            badDebt += bad;
            totalNormalizedDebt -= v.normalizedDebt;
            v.normalizedDebt = 0;
        }

        if (!collateralToken.transfer(msg.sender, seized)) revert TransferFailed();
        emit Liquidated(user, msg.sender, repaid, seized, bad);
    }

    function heal() external returns (uint256 healed) {
        healed = balanceOf[address(this)];
        if (healed > badDebt) healed = badDebt;
        badDebt -= healed;
        _burn(address(this), healed);
    }

    // ------------------------------------------------------------ stablecoin

    function transfer(address to, uint256 amount) external returns (bool) {
        _move(msg.sender, to, amount);
        return true;
    }

    function _move(address from, address to, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
    }
    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        balanceOf[from] -= amount;
        totalSupply -= amount;
    }
    function _mulUp(uint256 normalized, uint256 r) internal pure returns (uint256) {
        return (normalized * r + RAY - 1) / RAY;
    }
}
