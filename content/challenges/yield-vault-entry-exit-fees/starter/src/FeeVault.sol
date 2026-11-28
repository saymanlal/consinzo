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
        // TODO: Validate the fees (FeeTooHigh) and the recipient (ZeroAddress) before storing.
        asset = IERC20(asset_);
        depositFeeBps = depositFeeBps_;
        withdrawFeeBps = withdrawFeeBps_;
        feeRecipient = feeRecipient_;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        // TODO: 1:1 while there are no shares, otherwise assets * totalSupply / totalAssets.
        revert("NOT_IMPLEMENTED");
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        // TODO: 1:1 while there are no shares, otherwise shares * totalAssets / totalSupply.
        revert("NOT_IMPLEMENTED");
    }

    function previewDeposit(uint256 assets) public view returns (uint256 shares, uint256 fee) {
        // TODO: fee on the deposited assets, shares for the net amount.
        revert("NOT_IMPLEMENTED");
    }

    function previewRedeem(uint256 shares) public view returns (uint256 assetsOut, uint256 fee) {
        // TODO: fee on the gross value of the shares, assetsOut is the rest.
        revert("NOT_IMPLEMENTED");
    }

    function deposit(uint256 assets) external returns (uint256 shares) {
        // TODO: Validate, price the shares on the state before the deposit, pull assets,
        //       forward the fee, grow totalAssets by the net amount, mint, emit Deposited.
        revert("NOT_IMPLEMENTED");
    }

    function redeem(uint256 shares) external returns (uint256 assetsOut) {
        // TODO: Validate, burn, shrink totalAssets by the gross value, pay the fee and the user,
        //       emit Redeemed.
        revert("NOT_IMPLEMENTED");
    }

    function addYield(uint256 amount) external {
        // TODO: Validate (ZeroAmount, NoShareholders), pull tokens, grow totalAssets, emit YieldAdded.
        revert("NOT_IMPLEMENTED");
    }
}
