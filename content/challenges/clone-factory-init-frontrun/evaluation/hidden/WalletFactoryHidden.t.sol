// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/WalletFactory.sol";

contract WalletFactoryHiddenTest is Test {
    WalletFactory public factory;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public attacker = address(0xBAD);
    bytes32 internal constant SALT = keccak256("payroll");

    function setUp() public {
        factory = new WalletFactory();
    }

    function _create(address who, bytes32 salt) internal returns (CloneWallet) {
        vm.prank(who);
        address w = factory.createWallet(salt);
        return CloneWallet(payable(w));
    }

    function testHiddenSaltSquattingDoesNotBlockOrCaptureCreator() public {
        address planned = factory.predict(alice, SALT);

        // The attacker sees alice's pending transaction and uses her salt first.
        CloneWallet squat = _create(attacker, SALT);
        assertNotEq(address(squat), planned);
        assertEq(planned.code.length, 0);

        CloneWallet wallet = _create(alice, SALT);
        assertEq(address(wallet), planned);
        assertEq(wallet.owner(), alice);
        assertEq(squat.owner(), attacker);
    }

    function testHiddenPrefundedAddressBelongsToCreator() public {
        address planned = factory.predict(alice, SALT);
        vm.deal(planned, 5 ether); // counterfactual funding before deployment

        _create(attacker, SALT);
        vm.prank(attacker);
        (bool ok, ) = planned.call(abi.encodeWithSelector(CloneWallet.initialize.selector, attacker));
        ok; // no code there yet, nothing to initialise

        CloneWallet wallet = _create(alice, SALT);
        assertEq(address(wallet), planned);
        assertEq(wallet.owner(), alice);

        vm.expectRevert(CloneWallet.NotOwner.selector);
        vm.prank(attacker);
        wallet.withdraw(payable(attacker), 5 ether);
        assertEq(attacker.balance, 0);

        vm.prank(alice);
        wallet.withdraw(payable(alice), 5 ether);
        assertEq(alice.balance, 5 ether);
    }

    function testHiddenPredictIsPerCreator() public {
        assertNotEq(factory.predict(alice, SALT), factory.predict(bob, SALT));
        assertNotEq(factory.predict(alice, SALT), factory.predict(alice, keccak256("other")));
        CloneWallet b = _create(bob, SALT);
        assertEq(address(b), factory.predict(bob, SALT));
        assertEq(b.owner(), bob);
    }

    function testHiddenSameCreatorSameSaltReverts() public {
        _create(alice, SALT);
        vm.expectRevert();
        vm.prank(alice);
        factory.createWallet(SALT);
    }

    function testHiddenImplementationCannotBeInitialised() public {
        CloneWallet impl = CloneWallet(payable(factory.implementation()));
        vm.expectRevert();
        vm.prank(attacker);
        impl.initialize(attacker);
        assertEq(impl.owner(), address(0));
    }

    function testHiddenOwnerCannotBeReassignedByCreatorEither() public {
        CloneWallet wallet = _create(alice, SALT);
        vm.expectRevert(CloneWallet.AlreadyInitialized.selector);
        vm.prank(alice);
        wallet.initialize(bob);
        assertEq(wallet.owner(), alice);
        assertFalse(factory.isWallet(address(0xDEAD)));
    }

    function testHiddenWalletsAreIndependent() public {
        CloneWallet a = _create(alice, SALT);
        CloneWallet b = _create(bob, SALT);
        vm.deal(address(a), 1 ether);
        vm.deal(address(b), 2 ether);

        vm.expectRevert(CloneWallet.NotOwner.selector);
        vm.prank(bob);
        a.withdraw(payable(bob), 1 ether);
        assertEq(address(a).balance, 1 ether);

        vm.prank(bob);
        b.withdraw(payable(bob), 2 ether);
        assertEq(bob.balance, 2 ether);
    }
}
