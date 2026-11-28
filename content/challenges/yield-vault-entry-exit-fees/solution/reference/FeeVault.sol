// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract FeeVault {
    error FeeTooHigh();
    error ZeroAddress();
    error ZeroAmount();
    error ZeroShares();
    error InsufficientShares();
    error NoShareholders();
    error TransferFailed();

    event Deposited(address indexed user, uint256 assets, uint256 shares, uint256 fee);
    event Redeemed(address indexed user, uint256 shares, uint256 assetsOut, uint256 fee);
    event YieldAdded(address indexed from, uint256 amount);

    uint256 internal constant BPS = 10_000;
    uint256 public constant MAX_FEE_BPS = 1000;

    IERC20 public immutable asset;
    uint256 public immutable depositFeeBps;
    uint256 public immutable withdrawFeeBps;
    address public immutable feeRecipient;

    /// @notice Assets backing the shares. Tracked internally, never read from the token balance.
    uint256 public totalAssets;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(address asset_, uint256 depositFeeBps_, uint256 withdrawFeeBps_, address feeRecipient_) {
        if (depositFeeBps_ > MAX_FEE_BPS || withdrawFeeBps_ > MAX_FEE_BPS) revert FeeTooHigh();
        if (feeRecipient_ == address(0)) revert ZeroAddress();
        asset = IERC20(asset_);
        depositFeeBps = depositFeeBps_;
        withdrawFeeBps = withdrawFeeBps_;
        feeRecipient = feeRecipient_;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        return totalSupply == 0 ? assets : (assets * totalSupply) / totalAssets;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return totalSupply == 0 ? shares : (shares * totalAssets) / totalSupply;
    }

    function previewDeposit(uint256 assets) public view returns (uint256 shares, uint256 fee) {
        fee = (assets * depositFeeBps) / BPS;
        shares = convertToShares(assets - fee);
    }

    function previewRedeem(uint256 shares) public view returns (uint256 assetsOut, uint256 fee) {
        uint256 gross = convertToAssets(shares);
        fee = (gross * withdrawFeeBps) / BPS;
        assetsOut = gross - fee;
    }

    function _send(address to, uint256 amount) private {
        if (amount == 0) return;
        if (!asset.transfer(to, amount)) revert TransferFailed();
    }

    function deposit(uint256 assets) external returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();
        uint256 fee;
        (shares, fee) = previewDeposit(assets);
        // A deposit that would mint nothing would be a pure gift to existing holders.
        if (shares == 0) revert ZeroShares();

        totalAssets += assets - fee;
        totalSupply += shares;
        balanceOf[msg.sender] += shares;

        if (!asset.transferFrom(msg.sender, address(this), assets)) revert TransferFailed();
        _send(feeRecipient, fee);
        emit Deposited(msg.sender, assets, shares, fee);
    }

    function redeem(uint256 shares) external returns (uint256 assetsOut) {
        if (shares == 0) revert ZeroAmount();
        if (shares > balanceOf[msg.sender]) revert InsufficientShares();
        uint256 fee;
        (assetsOut, fee) = previewRedeem(shares);

        balanceOf[msg.sender] -= shares;
        totalSupply -= shares;
        // The whole gross value leaves the pool: part to the recipient, the rest to the user.
        totalAssets -= assetsOut + fee;

        _send(feeRecipient, fee);
        _send(msg.sender, assetsOut);
        emit Redeemed(msg.sender, shares, assetsOut, fee);
    }

    function addYield(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        // With no shares outstanding the yield would be captured by the next depositor.
        if (totalSupply == 0) revert NoShareholders();
        totalAssets += amount;
        if (!asset.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        emit YieldAdded(msg.sender, amount);
    }
}
