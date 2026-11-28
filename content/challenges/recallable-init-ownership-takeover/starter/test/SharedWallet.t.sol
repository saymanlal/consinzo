// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SharedWallet.sol";

contract SharedWalletTest is Test {
    SharedWallet public wallet;
    address public alice = address(0xA11CE);
    address public mallory = address(0xBAD);

    function setUp() public {
        wallet = new SharedWallet();
        wallet.init(alice);
        vm.deal(address(wallet), 5 ether);
    }

    function testInitSetsOwner() public {
        assertEq(wallet.owner(), alice);
        assertTrue(wallet.initialized());
    }

    function testOwnerCanWithdraw() public {
        vm.prank(alice);
        wallet.withdraw(payable(alice), 2 ether);
        assertEq(alice.balance, 2 ether);
        assertEq(address(wallet).balance, 3 ether);
    }

    function testSecondInitReverts() public {
        vm.prank(mallory);
        vm.expectRevert(SharedWallet.AlreadyInitialized.selector);
        wallet.init(mallory);
        assertEq(wallet.owner(), alice);
    }

    function testAttackerCannotTakeFundsAfterReinitAttempt() public {
        vm.prank(mallory);
        vm.expectRevert();
        wallet.init(mallory);

        vm.prank(mallory);
        vm.expectRevert(SharedWallet.NotOwner.selector);
        wallet.withdraw(payable(mallory), 5 ether);

        assertEq(mallory.balance, 0);
        assertEq(address(wallet).balance, 5 ether);
    }
}
