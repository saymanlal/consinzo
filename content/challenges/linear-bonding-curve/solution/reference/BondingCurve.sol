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
        return basePrice + (slope * totalSupply) / WAD;
    }

    function reserveFor(uint256 supply) public view returns (uint256) {
        return (basePrice * supply) / WAD + (slope * supply * supply) / (2 * WAD * WAD);
    }

    function buyCost(uint256 amount) public view returns (uint256) {
        return reserveFor(totalSupply + amount) - reserveFor(totalSupply);
    }

    function sellRefund(uint256 amount) public view returns (uint256) {
        return reserveFor(totalSupply) - reserveFor(totalSupply - amount);
    }

    function buy(uint256 amount) external payable returns (uint256 cost) {
        if (amount == 0) revert ZeroAmount();
        cost = buyCost(amount);
        if (msg.value < cost) revert InsufficientPayment();

        totalSupply += amount;
        balanceOf[msg.sender] += amount;
        reserve += cost;

        uint256 excess = msg.value - cost;
        if (excess > 0) {
            (bool ok, ) = msg.sender.call{value: excess}("");
            if (!ok) revert TransferFailed();
        }
        emit Bought(msg.sender, amount, cost);
    }

    function sell(uint256 amount, uint256 minRefund) external returns (uint256 refund) {
        if (amount == 0) revert ZeroAmount();
        if (amount > balanceOf[msg.sender]) revert InsufficientBalance();
        refund = sellRefund(amount);
        if (refund < minRefund) revert SlippageExceeded();

        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        reserve -= refund;

        (bool ok, ) = msg.sender.call{value: refund}("");
        if (!ok) revert TransferFailed();
        emit Sold(msg.sender, amount, refund);
    }
}
