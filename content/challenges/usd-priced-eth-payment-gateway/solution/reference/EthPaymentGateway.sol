// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Subset of the Chainlink AggregatorV3 interface used by the gateway.
interface IAggregatorV3 {
    function decimals() external view returns (uint8);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

contract EthPaymentGateway {
    struct Order {
        uint256 usdAmount; // USD, 18 decimals
        address payer;
        bool paid;
    }

    address public immutable owner;
    address public immutable merchant;
    IAggregatorV3 public immutable feed;
    uint256 public immutable maxAge;

    uint256 public proceeds;
    mapping(bytes32 => Order) public orders;

    error ZeroAddress();
    error NotOwner();
    error NotMerchant();
    error ZeroAmount();
    error OrderExists();
    error UnknownOrder();
    error AlreadyPaid();
    error InvalidPrice();
    error StalePrice();
    error InsufficientPayment(uint256 sent, uint256 due);
    error TransferFailed();

    event OrderCreated(bytes32 indexed orderId, uint256 usdAmount);
    event OrderPaid(bytes32 indexed orderId, address indexed payer, uint256 weiPaid);

    constructor(address feed_, uint256 maxAge_, address merchant_) {
        if (feed_ == address(0) || merchant_ == address(0)) revert ZeroAddress();
        owner = msg.sender;
        feed = IAggregatorV3(feed_);
        maxAge = maxAge_;
        merchant = merchant_;
    }

    function createOrder(bytes32 orderId, uint256 usdAmount) external {
        if (msg.sender != owner) revert NotOwner();
        if (usdAmount == 0) revert ZeroAmount();
        // usdAmount is never zero for a registered order, so it doubles as the existence flag.
        if (orders[orderId].usdAmount != 0) revert OrderExists();
        orders[orderId].usdAmount = usdAmount;
        emit OrderCreated(orderId, usdAmount);
    }

    function quote(bytes32 orderId) public view returns (uint256 weiDue) {
        uint256 usdAmount = orders[orderId].usdAmount;
        if (usdAmount == 0) revert UnknownOrder();
        weiDue = _toWei(usdAmount);
    }

    function pay(bytes32 orderId) external payable {
        Order storage order = orders[orderId];
        if (order.usdAmount == 0) revert UnknownOrder();
        if (order.paid) revert AlreadyPaid();

        uint256 weiDue = _toWei(order.usdAmount);
        if (msg.value < weiDue) revert InsufficientPayment(msg.value, weiDue);

        // Effects before the refund: the refund hands control to the payer.
        order.paid = true;
        order.payer = msg.sender;
        proceeds += weiDue;
        emit OrderPaid(orderId, msg.sender, weiDue);

        uint256 refund = msg.value - weiDue;
        if (refund != 0) {
            (bool ok,) = msg.sender.call{value: refund}("");
            if (!ok) revert TransferFailed();
        }
    }

    function withdraw() external {
        if (msg.sender != merchant) revert NotMerchant();
        uint256 amount = proceeds;
        proceeds = 0;
        (bool ok,) = merchant.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    /// @dev usd (18 decimals) / price (feed decimals) expressed in wei, rounded up.
    function _toWei(uint256 usdAmount) internal view returns (uint256) {
        (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();
        if (answer <= 0) revert InvalidPrice();
        if (updatedAt == 0 || updatedAt > block.timestamp) revert StalePrice();
        if (block.timestamp - updatedAt > maxAge) revert StalePrice();

        uint256 price = uint256(answer);
        uint256 numerator = usdAmount * 10 ** uint256(feed.decimals());
        // Ceiling division. numerator is non-zero because usdAmount is non-zero.
        return (numerator - 1) / price + 1;
    }
}
