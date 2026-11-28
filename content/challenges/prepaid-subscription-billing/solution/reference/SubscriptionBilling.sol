// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title Prepaid, merchant-triggered recurring billing in ETH.
contract SubscriptionBilling {
    struct Subscription {
        uint256 balance; // prepaid ETH not yet charged
        uint256 paidUntil; // end of the last period that has been paid for
        bool active;
    }

    address public immutable merchant;
    uint256 public immutable price;
    uint256 public immutable period;

    uint256 public merchantBalance;
    mapping(address => Subscription) public subscriptions;

    event Subscribed(address indexed subscriber, uint256 paidUntil);
    event Charged(address indexed subscriber, uint256 paidUntil);
    event Cancelled(address indexed subscriber, address indexed by);

    error InvalidConfig();
    error AlreadySubscribed();
    error NotSubscribed();
    error StillSubscribed();
    error InsufficientBalance();
    error ZeroAmount();
    error NotMerchant();
    error NotAuthorized();
    error NotDue();
    error NothingToWithdraw();
    error TransferFailed();

    constructor(uint256 _price, uint256 _period) {
        if (_price == 0 || _period == 0) revert InvalidConfig();
        merchant = msg.sender;
        price = _price;
        period = _period;
    }

    function subscribe() external payable {
        Subscription storage s = subscriptions[msg.sender];
        if (s.active) revert AlreadySubscribed();

        uint256 balance = s.balance + msg.value;
        if (balance < price) revert InsufficientBalance();

        // Periods are paid in advance, starting with the first one.
        s.balance = balance - price;
        merchantBalance += price;
        s.paidUntil = block.timestamp + period;
        s.active = true;
        emit Subscribed(msg.sender, s.paidUntil);
    }

    function topUp() external payable {
        if (msg.value == 0) revert ZeroAmount();
        subscriptions[msg.sender].balance += msg.value;
    }

    function charge(address subscriber) external {
        if (msg.sender != merchant) revert NotMerchant();
        Subscription storage s = subscriptions[subscriber];
        if (!s.active) revert NotSubscribed();
        if (block.timestamp < s.paidUntil) revert NotDue();
        if (s.balance < price) revert InsufficientBalance();

        s.balance -= price;
        merchantBalance += price;
        // Advancing from the old value (not from now) means a late charge neither gives
        // away free time nor lets the merchant bill a period twice.
        s.paidUntil += period;
        emit Charged(subscriber, s.paidUntil);
    }

    function cancel(address subscriber) external {
        if (msg.sender != subscriber && msg.sender != merchant) revert NotAuthorized();
        Subscription storage s = subscriptions[subscriber];
        if (!s.active) revert NotSubscribed();

        s.active = false;
        emit Cancelled(subscriber, msg.sender);
    }

    function withdraw() external {
        Subscription storage s = subscriptions[msg.sender];
        if (s.active) revert StillSubscribed();
        uint256 amount = s.balance;
        if (amount == 0) revert NothingToWithdraw();

        s.balance = 0;
        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    function collect() external {
        if (msg.sender != merchant) revert NotMerchant();
        uint256 amount = merchantBalance;
        if (amount == 0) revert NothingToWithdraw();

        merchantBalance = 0;
        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    function isPaid(address subscriber) external view returns (bool) {
        Subscription storage s = subscriptions[subscriber];
        return s.active && block.timestamp < s.paidUntil;
    }
}
