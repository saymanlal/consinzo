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

contract EthPaymentGatewayTest is Test {
    uint256 internal constant MAX_AGE = 1 hours;
    bytes32 internal constant ORDER = keccak256("order-1");

    MockAggregator public feed;
    EthPaymentGateway public gateway;
    address public merchant = address(0xBEEF);
    address public alice = address(0xA11CE);

    function setUp() public {
        feed = new MockAggregator(8);
        feed.setRound(2_000e8, block.timestamp);
        gateway = new EthPaymentGateway(address(feed), MAX_AGE, merchant);
        gateway.createOrder(ORDER, 100e18); // 100 USD
        vm.deal(alice, 10 ether);
    }

    function testQuoteConvertsUsdToWei() public {
        assertEq(gateway.quote(ORDER), 0.05 ether);
        feed.setRound(4_000e8, block.timestamp);
        assertEq(gateway.quote(ORDER), 0.025 ether);
    }

    function testPayExactAmount() public {
        vm.prank(alice);
        gateway.pay{value: 0.05 ether}(ORDER);

        (uint256 usdAmount, address payer, bool paid) = gateway.orders(ORDER);
        assertEq(usdAmount, 100e18);
        assertEq(payer, alice);
        assertTrue(paid);
        assertEq(gateway.proceeds(), 0.05 ether);
        assertEq(alice.balance, 9.95 ether);
    }

    function testOverpaymentIsRefunded() public {
        vm.prank(alice);
        gateway.pay{value: 1 ether}(ORDER);

        assertEq(alice.balance, 9.95 ether);
        assertEq(address(gateway).balance, 0.05 ether);
        assertEq(gateway.proceeds(), 0.05 ether);
    }

    function testUnderpaymentReverts() public {
        vm.prank(alice);
        vm.expectRevert(EthPaymentGateway.InsufficientPayment.selector);
        gateway.pay{value: 0.05 ether - 1}(ORDER);
    }

    function testCannotPayTwice() public {
        vm.prank(alice);
        gateway.pay{value: 0.05 ether}(ORDER);
        vm.prank(alice);
        vm.expectRevert(EthPaymentGateway.AlreadyPaid.selector);
        gateway.pay{value: 0.05 ether}(ORDER);
    }

    function testMerchantWithdraws() public {
        vm.prank(alice);
        gateway.pay{value: 0.2 ether}(ORDER);

        vm.prank(merchant);
        gateway.withdraw();
        assertEq(merchant.balance, 0.05 ether);
        assertEq(gateway.proceeds(), 0);
        assertEq(address(gateway).balance, 0);
    }
}
