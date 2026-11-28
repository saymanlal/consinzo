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

contract RevertingSigner {
    error SignerExploded();

    function isValidSignature(bytes32, bytes calldata) external pure returns (bytes4) {
        revert SignerExploded();
    }
}

/// Returns the four magic bytes without ABI padding.
contract ShortReturnSigner {
    fallback() external {
        assembly {
            mstore(0, 0x1626ba7e00000000000000000000000000000000000000000000000000000000)
            return(0, 4)
        }
    }
}

/// Returns the magic value right-aligned, which is not a valid bytes4 encoding of it.
contract MisalignedSigner {
    fallback() external {
        assembly {
            mstore(0, 0x1626ba7e)
            return(0, 32)
        }
    }
}

/// Accepts only when the forwarded signature bytes are the expected ones.
contract PasswordSigner {
    function isValidSignature(bytes32, bytes calldata signature) external pure returns (bytes4) {
        return keccak256(signature) == keccak256("open sesame") ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }
}

contract SignedWithdrawVaultHiddenTest is VaultFixture {
    function setUp() public {
        _deploy();
    }

    function _delegate(address signer, bool allowed) internal {
        vm.prank(walletOwner);
        wallet.exec(address(vault), 0, abi.encodeWithSelector(SignedWithdrawVault.setDelegate.selector, signer, allowed));
    }

    function testHiddenAnotherHonestWalletCannotAuthorise() public {
        address bobOwner = address(0xB0B);
        MockWallet bob = _newWallet(bobOwner, 1 ether);
        SignedWithdrawVault.Withdrawal memory w = _w(address(wallet), bobOwner, 10 ether, 0);
        _approve(bob, bobOwner, w);
        vm.prank(bobOwner);
        vm.expectRevert(SignedWithdrawVault.UnauthorizedSigner.selector);
        vault.withdrawWithSignature(w, address(bob), "");
        assertEq(vault.balanceOf(address(wallet)), 10 ether);
    }

    function testHiddenDelegateOfAnotherAccountCannotAuthorise() public {
        address bobOwner = address(0xB0B);
        MockWallet bob = _newWallet(bobOwner, 1 ether);
        AlwaysValidSigner fake = new AlwaysValidSigner();
        // Bob legitimately registers the signer for his own account.
        vm.prank(bobOwner);
        bob.exec(address(vault), 0, abi.encodeWithSelector(SignedWithdrawVault.setDelegate.selector, address(fake), true));

        SignedWithdrawVault.Withdrawal memory w = _w(address(wallet), bobOwner, 10 ether, 0);
        vm.expectRevert(SignedWithdrawVault.UnauthorizedSigner.selector);
        vault.withdrawWithSignature(w, address(fake), "");

        // The same signer does work for Bob's own balance.
        SignedWithdrawVault.Withdrawal memory own = _w(address(bob), payee, 1 ether, 0);
        vault.withdrawWithSignature(own, address(fake), "");
        assertEq(payee.balance, 1 ether);
        assertEq(vault.balanceOf(address(wallet)), 10 ether);
    }

    function testHiddenRevokedDelegateLosesAuthority() public {
        AlwaysValidSigner module = new AlwaysValidSigner();
        _delegate(address(module), true);
        vault.withdrawWithSignature(_w(address(wallet), payee, 1 ether, 0), address(module), "");
        _delegate(address(module), false);
        SignedWithdrawVault.Withdrawal memory w = _w(address(wallet), payee, 1 ether, 1);
        vm.expectRevert(SignedWithdrawVault.UnauthorizedSigner.selector);
        vault.withdrawWithSignature(w, address(module), "");
        assertEq(payee.balance, 1 ether);
    }

    function testHiddenHostileSignersYieldInvalidSignature() public {
        RevertingSigner r = new RevertingSigner();
        ShortReturnSigner s = new ShortReturnSigner();
        MisalignedSigner m = new MisalignedSigner();
        address eoa = address(0xE0A);
        _delegate(address(r), true);
        _delegate(address(s), true);
        _delegate(address(m), true);
        _delegate(eoa, true);
        SignedWithdrawVault.Withdrawal memory w = _w(address(wallet), attacker, 1 ether, 0);

        vm.expectRevert(SignedWithdrawVault.InvalidSignature.selector);
        vault.withdrawWithSignature(w, address(r), "");
        vm.expectRevert(SignedWithdrawVault.InvalidSignature.selector);
        vault.withdrawWithSignature(w, address(s), "");
        vm.expectRevert(SignedWithdrawVault.InvalidSignature.selector);
        vault.withdrawWithSignature(w, address(m), "");
        vm.expectRevert(SignedWithdrawVault.InvalidSignature.selector);
        vault.withdrawWithSignature(w, eoa, "");
        assertEq(vault.balanceOf(address(wallet)), 10 ether);
        assertEq(vault.nonces(address(wallet)), 0);
    }

    function testHiddenSignatureBytesAreForwarded() public {
        PasswordSigner p = new PasswordSigner();
        _delegate(address(p), true);
        SignedWithdrawVault.Withdrawal memory w = _w(address(wallet), payee, 2 ether, 0);
        vm.expectRevert(SignedWithdrawVault.InvalidSignature.selector);
        vault.withdrawWithSignature(w, address(p), "wrong");
        vault.withdrawWithSignature(w, address(p), "open sesame");
        assertEq(payee.balance, 2 ether);
    }

    function testHiddenApprovalBindsEveryField() public {
        SignedWithdrawVault.Withdrawal memory w = _w(address(wallet), payee, 1 ether, 0);
        _approve(wallet, walletOwner, w);

        SignedWithdrawVault.Withdrawal memory moreMoney = _w(address(wallet), payee, 9 ether, 0);
        vm.expectRevert(SignedWithdrawVault.InvalidSignature.selector);
        vault.withdrawWithSignature(moreMoney, address(wallet), "");

        SignedWithdrawVault.Withdrawal memory otherPayee = _w(address(wallet), attacker, 1 ether, 0);
        vm.expectRevert(SignedWithdrawVault.InvalidSignature.selector);
        vault.withdrawWithSignature(otherPayee, address(wallet), "");

        SignedWithdrawVault.Withdrawal memory later = _w(address(wallet), payee, 1 ether, 0);
        later.deadline = w.deadline + 1;
        vm.expectRevert(SignedWithdrawVault.InvalidSignature.selector);
        vault.withdrawWithSignature(later, address(wallet), "");

        bytes32 expected = keccak256(
            abi.encode(vault.WITHDRAWAL_TYPEHASH(), block.chainid, address(vault), w.account, w.to, w.amount, w.nonce, w.deadline)
        );
        assertEq(vault.hashWithdrawal(w), expected);
        vault.withdrawWithSignature(w, address(wallet), "");
        assertEq(payee.balance, 1 ether);
    }

    function testHiddenExpiryNonceAndBalance() public {
        SignedWithdrawVault.Withdrawal memory w = _w(address(wallet), payee, 1 ether, 0);
        _approve(wallet, walletOwner, w);
        SignedWithdrawVault.Withdrawal memory future = _w(address(wallet), payee, 1 ether, 1);
        _approve(wallet, walletOwner, future);
        vm.expectRevert(SignedWithdrawVault.InvalidNonce.selector);
        vault.withdrawWithSignature(future, address(wallet), "");

        SignedWithdrawVault.Withdrawal memory tooMuch = _w(address(wallet), payee, 11 ether, 0);
        _approve(wallet, walletOwner, tooMuch);
        vm.expectRevert(SignedWithdrawVault.InsufficientBalance.selector);
        vault.withdrawWithSignature(tooMuch, address(wallet), "");

        vm.warp(w.deadline + 1);
        vm.expectRevert(SignedWithdrawVault.Expired.selector);
        vault.withdrawWithSignature(w, address(wallet), "");
        assertEq(vault.balanceOf(address(wallet)), 10 ether);
    }

    function testHiddenDirectWithdrawStillWorks() public {
        vm.prank(walletOwner);
        wallet.exec(address(vault), 0, abi.encodeWithSelector(SignedWithdrawVault.withdraw.selector, 4 ether));
        assertEq(address(wallet).balance, 4 ether);
        assertEq(vault.balanceOf(address(wallet)), 6 ether);
    }
}
