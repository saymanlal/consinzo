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
        // TODO: reject zero feed_ / merchant_ with ZeroAddress()
        owner = msg.sender;
        feed = IAggregatorV3(feed_);
        maxAge = maxAge_;
        merchant = merchant_;
    }

    function createOrder(bytes32 orderId, uint256 usdAmount) external {
        // TODO: owner only, non-zero amount, each orderId registered once, emit OrderCreated
        revert("NOT_IMPLEMENTED");
    }

    function quote(bytes32 orderId) public view returns (uint256 weiDue) {
        // TODO: UnknownOrder() for unregistered ids
        // TODO: validate the feed answer (InvalidPrice / StalePrice)
        // TODO: weiDue = ceil(usdAmount * 10 ** feedDecimals / answer)
        revert("NOT_IMPLEMENTED");
    }

    function pay(bytes32 orderId) external payable {
        // TODO: UnknownOrder / AlreadyPaid / InsufficientPayment checks
        // TODO: mark paid, record payer, credit proceeds, emit OrderPaid
        // TODO: refund msg.value - weiDue to the payer (TransferFailed on failure)
        revert("NOT_IMPLEMENTED");
    }

    function withdraw() external {
        // TODO: merchant only; zero proceeds, then send them to the merchant
        revert("NOT_IMPLEMENTED");
    }
}
