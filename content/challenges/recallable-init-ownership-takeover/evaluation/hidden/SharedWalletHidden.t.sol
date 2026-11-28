// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SharedWallet.sol";

/// Re-initialises and drains in a single transaction.
contract TakeoverBot {
    function run(SharedWallet wallet) external returns (bool stolen) {
        (bool ok, ) = address(wallet).call(abi.encodeCall(SharedWallet.init, (address(this))));
        if (!ok) return false;
        (ok, ) = address(wallet).call(
            abi.encodeCall(SharedWallet.withdraw, (payable(address(this)), address(wallet).balance))
        );
        return ok;
    }

    receive() external payable {}
}

contract SharedWalletHiddenTest is Test {
    SharedWallet public wallet;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public mallory = address(0xBAD);

    function setUp() public {
        wallet = new SharedWallet();
        vm.deal(address(wallet), 4 ether);
    }

    function testHiddenAtomicTakeoverFails() public {
        wallet.init(alice);
        TakeoverBot bot = new TakeoverBot();
        assertFalse(bot.run(wallet));
        assertEq(wallet.owner(), alice);
        assertEq(address(bot).balance, 0);
        assertEq(address(wallet).balance, 4 ether);
    }

    function testHiddenOwnerCannotReinitEither() public {
        wallet.init(alice);
        vm.prank(alice);
        vm.expectRevert(SharedWallet.AlreadyInitialized.selector);
        wallet.init(bob);
        assertEq(wallet.owner(), alice);
    }

    function testHiddenReinitWithSameOwnerReverts() public {
        wallet.init(alice);
        vm.expectRevert(SharedWallet.AlreadyInitialized.selector);
        wallet.init(alice);
    }

    function testHiddenReinitWithZeroAddressCannotClearOwner() public {
        wallet.init(alice);
        vm.prank(mallory);
        vm.expectRevert();
        wallet.init(address(0));
        assertEq(wallet.owner(), alice);
        assertTrue(wallet.initialized());
    }

    function testHiddenZeroAddressInitDoesNotConsumeSetup() public {
        vm.expectRevert(SharedWallet.ZeroAddress.selector);
        wallet.init(address(0));
        assertFalse(wallet.initialized());
        assertEq(wallet.owner(), address(0));

        wallet.init(bob);
        assertEq(wallet.owner(), bob);
        assertTrue(wallet.initialized());
    }

    function testHiddenNobodyWithdrawsBeforeInit() public {
        vm.prank(mallory);
        vm.expectRevert(SharedWallet.NotOwner.selector);
        wallet.withdraw(payable(mallory), 1 ether);
        assertEq(address(wallet).balance, 4 ether);
    }

    function testHiddenWithdrawValidation() public {
        wallet.init(alice);
        vm.prank(alice);
        vm.expectRevert(SharedWallet.InsufficientBalance.selector);
        wallet.withdraw(payable(alice), 4 ether + 1);

        vm.prank(alice);
        vm.expectRevert(SharedWallet.ZeroAddress.selector);
        wallet.withdraw(payable(address(0)), 1 ether);

        vm.prank(alice);
        wallet.withdraw(payable(bob), 4 ether);
        assertEq(bob.balance, 4 ether);
        assertEq(address(wallet).balance, 0);
    }
}
