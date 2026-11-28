// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/EthPaymentGateway.sol";

contract MockAggregator is IAggregatorV3 {
    uint8 public override decimals;
    int256 public answer;
    uint256 public updatedAt;

    constructor(uint8 decimals_) {
        decimals = decimals_;
    }

    function setRound(int256 answer_, uint256 updatedAt_) external {
        answer = answer_;
        updatedAt = updatedAt_;
    }

    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (1, answer, updatedAt, updatedAt, 1);
    }
}

/// Payer with no way to receive ETH: any refund to it fails.
contract NoReceivePayer {
    function payOrder(EthPaymentGateway gateway, bytes32 orderId) external payable {
        gateway.pay{value: msg.value}(orderId);
    }
}

/// Payer that tries to pay the same order again from inside its refund.
contract ReentrantPayer {
    EthPaymentGateway public gateway;
    bytes32 public orderId;
    bool public reentered;
    bool public reentrySucceeded;

    function payOrder(EthPaymentGateway gateway_, bytes32 orderId_) external payable {
        gateway = gateway_;
        orderId = orderId_;
        gateway_.pay{value: msg.value}(orderId_);
    }

    receive() external payable {
        if (!reentered) {
            reentered = true;
            try gateway.pay{value: msg.value}(orderId) {
                reentrySucceeded = true;
            } catch {}
        }
    }
}

contract EthPaymentGatewayHiddenTest is Test {
    uint256 internal constant MAX_AGE = 1 hours;
    bytes32 internal constant ORDER = keccak256("order-1");

    MockAggregator public feed;
    EthPaymentGateway public gateway;
    address public merchant = address(0xBEEF);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        feed = new MockAggregator(8);
        feed.setRound(2_000e8, block.timestamp);
        gateway = new EthPaymentGateway(address(feed), MAX_AGE, merchant);
        gateway.createOrder(ORDER, 100e18);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function testHiddenConstructorRejectsZeroAddresses() public {
        vm.expectRevert(EthPaymentGateway.ZeroAddress.selector);
        new EthPaymentGateway(address(0), MAX_AGE, merchant);
        vm.expectRevert(EthPaymentGateway.ZeroAddress.selector);
        new EthPaymentGateway(address(feed), MAX_AGE, address(0));
    }

    function testHiddenCreateOrderGuards() public {
        vm.prank(alice);
        vm.expectRevert(EthPaymentGateway.NotOwner.selector);
        gateway.createOrder(keccak256("x"), 1e18);

        vm.expectRevert(EthPaymentGateway.ZeroAmount.selector);
        gateway.createOrder(keccak256("x"), 0);

        vm.expectRevert(EthPaymentGateway.OrderExists.selector);
        gateway.createOrder(ORDER, 5e18);

        (uint256 usdAmount,,) = gateway.orders(ORDER);
        assertEq(usdAmount, 100e18);
    }

    function testHiddenUnknownOrder() public {
        vm.expectRevert(EthPaymentGateway.UnknownOrder.selector);
        gateway.quote(keccak256("missing"));

        vm.prank(alice);
        vm.expectRevert(EthPaymentGateway.UnknownOrder.selector);
        gateway.pay{value: 1 ether}(keccak256("missing"));
    }

    function testHiddenQuoteRoundsUp() public {
        bytes32 id = keccak256("odd");
        gateway.createOrder(id, 100e18);
        feed.setRound(3_000e8, block.timestamp);
        // 100 / 3000 ETH = 0.0333... ETH, rounded up to the next wei
        assertEq(gateway.quote(id), 33_333_333_333_333_334);

        vm.prank(alice);
        vm.expectRevert(EthPaymentGateway.InsufficientPayment.selector);
        gateway.pay{value: 33_333_333_333_333_333}(id);

        vm.prank(alice);
        gateway.pay{value: 33_333_333_333_333_334}(id);
        assertEq(gateway.proceeds(), 33_333_333_333_333_334);
    }

    function testHiddenExactDivisionIsNotRoundedUp() public {
        bytes32 id = keccak256("tiny");
        gateway.createOrder(id, 2_000); // 2000 wei-USD at 2000 USD/ETH is exactly 1 wei
        assertEq(gateway.quote(id), 1);
        gateway.createOrder(keccak256("tinier"), 1);
        assertEq(gateway.quote(keccak256("tinier")), 1); // never free
    }

    function testHiddenOtherFeedDecimals() public {
        MockAggregator f18 = new MockAggregator(18);
        f18.setRound(2_500e18, block.timestamp);
        EthPaymentGateway g = new EthPaymentGateway(address(f18), MAX_AGE, merchant);
        g.createOrder(ORDER, 50e18);
        assertEq(g.quote(ORDER), 0.02 ether);

        MockAggregator f0 = new MockAggregator(0);
        f0.setRound(2_500, block.timestamp);
        EthPaymentGateway g0 = new EthPaymentGateway(address(f0), MAX_AGE, merchant);
        g0.createOrder(ORDER, 50e18);
        assertEq(g0.quote(ORDER), 0.02 ether);
    }

    function testHiddenInvalidPriceBlocksQuoteAndPay() public {
        feed.setRound(0, block.timestamp);
        vm.expectRevert(EthPaymentGateway.InvalidPrice.selector);
        gateway.quote(ORDER);

        feed.setRound(-2_000e8, block.timestamp);
        vm.prank(alice);
        vm.expectRevert(EthPaymentGateway.InvalidPrice.selector);
        gateway.pay{value: 10 ether}(ORDER);
        assertEq(alice.balance, 10 ether);
    }

    function testHiddenStalenessBoundary() public {
        uint256 t0 = block.timestamp;
        vm.warp(t0 + MAX_AGE);
        assertEq(gateway.quote(ORDER), 0.05 ether);

        vm.warp(t0 + MAX_AGE + 1);
        vm.expectRevert(EthPaymentGateway.StalePrice.selector);
        gateway.quote(ORDER);
        vm.prank(alice);
        vm.expectRevert(EthPaymentGateway.StalePrice.selector);
        gateway.pay{value: 1 ether}(ORDER);

        feed.setRound(2_000e8, 0);
        vm.expectRevert(EthPaymentGateway.StalePrice.selector);
        gateway.quote(ORDER);

        feed.setRound(2_000e8, block.timestamp + 1);
        vm.expectRevert(EthPaymentGateway.StalePrice.selector);
        gateway.quote(ORDER);
    }

    function testHiddenPriceUsedIsThePriceAtPayment() public {
        feed.setRound(1_000e8, block.timestamp); // ETH halves: twice as much ETH is due
        vm.prank(alice);
        vm.expectRevert(EthPaymentGateway.InsufficientPayment.selector);
        gateway.pay{value: 0.05 ether}(ORDER);

        vm.prank(alice);
        gateway.pay{value: 0.5 ether}(ORDER);
        assertEq(gateway.proceeds(), 0.1 ether);
        assertEq(alice.balance, 9.9 ether);
    }

    function testHiddenRefundRejectedRevertsWholePayment() public {
        NoReceivePayer payer = new NoReceivePayer();
        vm.expectRevert(EthPaymentGateway.TransferFailed.selector);
        payer.payOrder{value: 1 ether}(gateway, ORDER);

        (,, bool paid) = gateway.orders(ORDER);
        assertFalse(paid);
        assertEq(gateway.proceeds(), 0);

        // Exact payment needs no refund, so the same payer succeeds.
        payer.payOrder{value: 0.05 ether}(gateway, ORDER);
        (, address recorded, bool paidNow) = gateway.orders(ORDER);
        assertTrue(paidNow);
        assertEq(recorded, address(payer));
    }

    function testHiddenReentrantPayerCannotPayTwice() public {
        ReentrantPayer payer = new ReentrantPayer();
        payer.payOrder{value: 1 ether}(gateway, ORDER);

        assertTrue(payer.reentered());
        assertFalse(payer.reentrySucceeded());
        assertEq(gateway.proceeds(), 0.05 ether);
        assertEq(address(gateway).balance, 0.05 ether);
        assertEq(address(payer).balance, 0.95 ether);
    }

    function testHiddenProceedsAccumulateAcrossOrders() public {
        bytes32 second = keccak256("order-2");
        gateway.createOrder(second, 300e18);

        vm.prank(alice);
        gateway.pay{value: 1 ether}(ORDER);
        vm.prank(bob);
        gateway.pay{value: 1 ether}(second);

        assertEq(gateway.proceeds(), 0.2 ether);
        assertEq(address(gateway).balance, 0.2 ether);
        (, address payer2,) = gateway.orders(second);
        assertEq(payer2, bob);

        // quote still answers for a paid order
        assertEq(gateway.quote(second), 0.15 ether);
    }

    function testHiddenWithdrawAccessAndIdempotence() public {
        vm.prank(alice);
        gateway.pay{value: 0.05 ether}(ORDER);

        vm.prank(alice);
        vm.expectRevert(EthPaymentGateway.NotMerchant.selector);
        gateway.withdraw();
        vm.expectRevert(EthPaymentGateway.NotMerchant.selector);
        gateway.withdraw(); // the owner is not the merchant

        vm.prank(merchant);
        gateway.withdraw();
        vm.prank(merchant);
        gateway.withdraw(); // nothing left, nothing sent
        assertEq(merchant.balance, 0.05 ether);
    }
}
