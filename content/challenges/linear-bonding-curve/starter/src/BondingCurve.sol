// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract BondingCurve {
    error ZeroAmount();
    error InsufficientPayment();
    error InsufficientBalance();
    error SlippageExceeded();
    error TransferFailed();

    event Bought(address indexed buyer, uint256 amount, uint256 cost);
    event Sold(address indexed seller, uint256 amount, uint256 refund);

    uint256 internal constant WAD = 1e18;

    /// @notice Price of the first token, in wei per whole token (1e18 base units).
    uint256 public immutable basePrice;
    /// @notice Price increase per whole token of supply, in wei per whole token.
    uint256 public immutable slope;

    uint256 public totalSupply;
    /// @notice ETH that backs the current supply. Always equals reserveFor(totalSupply).
    uint256 public reserve;
    mapping(address => uint256) public balanceOf;

    constructor(uint256 basePrice_, uint256 slope_) {
        basePrice = basePrice_;
        slope = slope_;
    }

    function currentPrice() external view returns (uint256) {
        // TODO: basePrice + slope * totalSupply / 1e18
        revert("NOT_IMPLEMENTED");
    }

    function reserveFor(uint256 supply) public view returns (uint256) {
        // TODO: Area under the price line from 0 to `supply` (two terms, each rounded down).
        revert("NOT_IMPLEMENTED");
    }

    function buyCost(uint256 amount) public view returns (uint256) {
        // TODO: reserveFor(totalSupply + amount) - reserveFor(totalSupply)
        revert("NOT_IMPLEMENTED");
    }

    function sellRefund(uint256 amount) public view returns (uint256) {
        // TODO: reserveFor(totalSupply) - reserveFor(totalSupply - amount)
        revert("NOT_IMPLEMENTED");
    }

    function buy(uint256 amount) external payable returns (uint256 cost) {
        // TODO: Validate, mint, grow the reserve by the cost, return excess ETH, emit Bought.
        revert("NOT_IMPLEMENTED");
    }

    function sell(uint256 amount, uint256 minRefund) external returns (uint256 refund) {
        // TODO: Validate, burn, shrink the reserve by the refund, pay the seller, emit Sold.
        revert("NOT_IMPLEMENTED");
    }
}
