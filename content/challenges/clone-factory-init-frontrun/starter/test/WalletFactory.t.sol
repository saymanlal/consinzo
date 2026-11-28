// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/WalletFactory.sol";

contract WalletFactoryTest is Test {
    WalletFactory public factory;
    address public alice = address(0xA11CE);
    address public attacker = address(0xBAD);
    bytes32 internal constant SALT = keccak256("alice-main");

    function setUp() public {
        factory = new WalletFactory();
    }

    function _create(address who, bytes32 salt) internal returns (CloneWallet) {
        vm.prank(who);
        address w = factory.createWallet(salt);
        return CloneWallet(payable(w));
    }

    function testWalletIsInitialisedForCreator() public {
        CloneWallet wallet = _create(alice, SALT);
        assertTrue(wallet.initialized());
        assertEq(wallet.owner(), alice);
        assertTrue(factory.isWallet(address(wallet)));
    }

    function testFrontRunnerCannotInitialise() public {
        CloneWallet wallet = _create(alice, SALT);
        vm.expectRevert(CloneWallet.AlreadyInitialized.selector);
        vm.prank(attacker);
        wallet.initialize(attacker);
        assertEq(wallet.owner(), alice);
    }

    function testCreatorControlsFunds() public {
        CloneWallet wallet = _create(alice, SALT);
        vm.deal(address(wallet), 3 ether);
        vm.prank(alice);
        wallet.withdraw(payable(alice), 1 ether);
        assertEq(alice.balance, 1 ether);
        assertEq(address(wallet).balance, 2 ether);
    }

    function testPredictMatchesDeployment() public {
        address expected = factory.predict(alice, SALT);
        CloneWallet wallet = _create(alice, SALT);
        assertEq(address(wallet), expected);
    }
}
