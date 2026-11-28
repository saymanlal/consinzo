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
        // TODO: Return weiAmount * rate / 1e18.
        revert("NOT_IMPLEMENTED");
    }

    function remainingCap() external view returns (uint256) {
        // TODO: Return the wei that can still be raised before the hard cap.
        revert("NOT_IMPLEMENTED");
    }

    function buy() external payable {
        // TODO: Check ZeroAmount, HardCapExceeded, BuyerLimitExceeded (in that order),
        //       update totalRaised and contributed, transfer the tokens, emit Purchased.
        revert("NOT_IMPLEMENTED");
    }

    function withdraw() external {
        // TODO: Only owner. Send the whole ETH balance to owner, emit Withdrawn.
        revert("NOT_IMPLEMENTED");
    }
}
