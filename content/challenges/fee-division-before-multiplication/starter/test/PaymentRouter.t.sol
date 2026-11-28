// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PaymentRouter.sol";

contract PaymentRouterTest is Test {
    PaymentRouter public router;
    address public treasury = address(0x7EA5);
    address public shop = address(0x5407);
    address public buyer = address(0xB0B);

    function setUp() public {
        router = new PaymentRouter(treasury, 250); // 2.5%
        vm.deal(buyer, 10 ether);
    }

    function testFeeOnRoundAmount() public {
        assertEq(router.quoteFee(1 ether), 0.025 ether);
        assertEq(router.quoteFee(10_000), 250);
    }

    function testSmallAmountStillPaysFee() public {
        // 9_999 * 250 / 10_000 = 249.975 -> 249
        assertEq(router.quoteFee(9_999), 249);
        assertEq(router.quoteFee(400), 10);
    }

    function testFeeOnNonMultipleAmount() public {
        // 12_345 * 250 / 10_000 = 308.625 -> 308
        assertEq(router.quoteFee(12_345), 308);
    }

    function testPaySplitsValueBetweenPayeeAndFees() public {
        vm.prank(buyer);
        router.pay{value: 9_999}(shop);
        assertEq(shop.balance, 9_750);
        assertEq(router.accruedFees(), 249);
        assertEq(address(router).balance, 249);
    }
}
