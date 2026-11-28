// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SignedWithdrawVault.sol";

/// Contract wallet (also usable as a delegate signer module): its owner approves hashes.
contract MockWallet {
    address public owner = msg.sender;
    mapping(bytes32 => bool) public approved;

    receive() external payable {}

    function approveHash(bytes32 h) external {
        require(msg.sender == owner, "OWNER");
        approved[h] = true;
    }

    function exec(address target, uint256 value, bytes calldata data) external {
        require(msg.sender == owner, "OWNER");
        (bool ok, ) = target.call{value: value}(data);
        require(ok, "EXEC");
    }

    function isValidSignature(bytes32 h, bytes calldata) external view returns (bytes4) {
        return approved[h] ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }
}

/// The attacker's signer: approves everything.
contract AlwaysValidSigner {
    function isValidSignature(bytes32, bytes calldata) external pure returns (bytes4) {
        return 0x1626ba7e;
    }
}

abstract contract VaultFixture is Test {
    SignedWithdrawVault internal vault;
    MockWallet internal wallet;
    address internal walletOwner = address(0xA11CE);
    address internal relayer = address(0x4E1A);
    address internal attacker = address(0xBAD);
    address internal payee = address(0xBEEF);

    function _deploy() internal {
        vault = new SignedWithdrawVault();
        wallet = _newWallet(walletOwner, 10 ether);
    }

    function _newWallet(address owner_, uint256 depositAmount) internal returns (MockWallet w) {
        vm.prank(owner_);
        w = new MockWallet();
        if (depositAmount > 0) {
            vm.deal(address(w), depositAmount);
            vm.prank(owner_);
            w.exec(address(vault), depositAmount, abi.encodeWithSelector(SignedWithdrawVault.deposit.selector));
        }
    }

    function _w(address account, address to, uint256 amount, uint256 nonce)
        internal
        view
        returns (SignedWithdrawVault.Withdrawal memory)
    {
        return SignedWithdrawVault.Withdrawal(account, to, amount, nonce, block.timestamp + 1 hours);
    }

    function _approve(MockWallet signer, address signerOwner, SignedWithdrawVault.Withdrawal memory w) internal {
        bytes32 h = vault.hashWithdrawal(w);
        vm.prank(signerOwner);
        signer.approveHash(h);
    }
}

contract SignedWithdrawVaultTest is VaultFixture {
    function setUp() public {
        _deploy();
    }

    function testCallerNamedSignerCannotDrainWallet() public {
        AlwaysValidSigner fake = new AlwaysValidSigner();
        SignedWithdrawVault.Withdrawal memory w = _w(address(wallet), attacker, 10 ether, 0);
        vm.prank(attacker);
        vm.expectRevert(SignedWithdrawVault.UnauthorizedSigner.selector);
        vault.withdrawWithSignature(w, address(fake), "");
        assertEq(vault.balanceOf(address(wallet)), 10 ether);
        assertEq(attacker.balance, 0);
    }

    function testAccountApprovedWithdrawalIsRelayed() public {
        SignedWithdrawVault.Withdrawal memory w = _w(address(wallet), payee, 3 ether, 0);
        _approve(wallet, walletOwner, w);
        vm.prank(relayer);
        vault.withdrawWithSignature(w, address(wallet), "");
        assertEq(payee.balance, 3 ether);
        assertEq(vault.balanceOf(address(wallet)), 7 ether);
        assertEq(vault.nonces(address(wallet)), 1);
    }

    function testRegisteredDelegateCanAuthorise() public {
        address operator = address(0x0931);
        vm.prank(operator);
        MockWallet module = new MockWallet();
        vm.prank(walletOwner);
        wallet.exec(address(vault), 0, abi.encodeWithSelector(SignedWithdrawVault.setDelegate.selector, address(module), true));

        SignedWithdrawVault.Withdrawal memory w = _w(address(wallet), payee, 1 ether, 0);
        _approve(module, operator, w);
        vm.prank(relayer);
        vault.withdrawWithSignature(w, address(module), "");
        assertEq(payee.balance, 1 ether);
    }

    function testUnapprovedHashIsRejected() public {
        SignedWithdrawVault.Withdrawal memory w = _w(address(wallet), attacker, 1 ether, 0);
        vm.prank(attacker);
        vm.expectRevert(SignedWithdrawVault.InvalidSignature.selector);
        vault.withdrawWithSignature(w, address(wallet), "");
    }

    function testReplayIsRejected() public {
        SignedWithdrawVault.Withdrawal memory w = _w(address(wallet), payee, 1 ether, 0);
        _approve(wallet, walletOwner, w);
        vault.withdrawWithSignature(w, address(wallet), "");
        vm.expectRevert(SignedWithdrawVault.InvalidNonce.selector);
        vault.withdrawWithSignature(w, address(wallet), "");
        assertEq(payee.balance, 1 ether);
    }
}
