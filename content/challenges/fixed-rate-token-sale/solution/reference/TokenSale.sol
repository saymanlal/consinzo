// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenSale {
    error ZeroAmount();
    error HardCapExceeded();
    error BuyerLimitExceeded();
    error NotOwner();
    error TransferFailed();

    event Purchased(address indexed buyer, uint256 weiPaid, uint256 tokensOut);
    event Withdrawn(address indexed to, uint256 amount);

    IERC20 public immutable token;
    address public immutable owner;
    /// @notice Token base units sold per 1 ETH (1e18 wei).
    uint256 public immutable rate;
    /// @notice Lifetime cap on ETH raised, in wei.
    uint256 public immutable hardCap;
    /// @notice Lifetime cap on ETH contributed by a single buyer, in wei.
    uint256 public immutable buyerLimit;

    uint256 public totalRaised;
    mapping(address => uint256) public contributed;

    constructor(address token_, uint256 rate_, uint256 hardCap_, uint256 buyerLimit_) {
        token = IERC20(token_);
        owner = msg.sender;
        rate = rate_;
        hardCap = hardCap_;
        buyerLimit = buyerLimit_;
    }

    function tokensFor(uint256 weiAmount) public view returns (uint256) {
        return (weiAmount * rate) / 1e18;
    }

    function remainingCap() external view returns (uint256) {
        return hardCap - totalRaised;
    }

    function buy() external payable {
        if (msg.value == 0) revert ZeroAmount();
        if (totalRaised + msg.value > hardCap) revert HardCapExceeded();
        uint256 newContribution = contributed[msg.sender] + msg.value;
        if (newContribution > buyerLimit) revert BuyerLimitExceeded();

        // Effects before the external token call.
        totalRaised += msg.value;
        contributed[msg.sender] = newContribution;

        uint256 tokensOut = tokensFor(msg.value);
        if (!token.transfer(msg.sender, tokensOut)) revert TransferFailed();

        emit Purchased(msg.sender, msg.value, tokensOut);
    }

    function withdraw() external {
        if (msg.sender != owner) revert NotOwner();
        uint256 amount = address(this).balance;
        (bool ok, ) = owner.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit Withdrawn(owner, amount);
    }
}
