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
        // TODO: Reject an already active subscription. Add msg.value to the balance and require at least `price`.
        // TODO: Charge the first period, set paidUntil and active, emit Subscribed.
        revert("NOT_IMPLEMENTED");
    }

    function topUp() external payable {
        // TODO: Reject a zero value, otherwise add msg.value to the caller's balance.
        revert("NOT_IMPLEMENTED");
    }

    function charge(address subscriber) external {
        // TODO: Merchant only; active subscription; the paid period must be over; balance must cover price.
        // TODO: Move price to merchantBalance and advance paidUntil by exactly one period; emit Charged.
        revert("NOT_IMPLEMENTED");
    }

    function cancel(address subscriber) external {
        // TODO: Only the subscriber or the merchant; subscription must be active. Deactivate and emit Cancelled.
        revert("NOT_IMPLEMENTED");
    }

    function withdraw() external {
        // TODO: Only when the caller's subscription is inactive. Pay out the whole remaining balance.
        revert("NOT_IMPLEMENTED");
    }

    function collect() external {
        // TODO: Merchant only. Pay out merchantBalance and zero it.
        revert("NOT_IMPLEMENTED");
    }

    function isPaid(address subscriber) external view returns (bool) {
        // TODO: True while the subscription is active and the paid period has not ended.
        revert("NOT_IMPLEMENTED");
    }
}
