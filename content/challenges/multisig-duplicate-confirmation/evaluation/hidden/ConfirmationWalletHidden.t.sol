// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ConfirmationWallet.sol";

contract WalletDeployer {
    function deploy(address[] memory owners, uint256 threshold) external returns (ConfirmationWallet) {
        return new ConfirmationWallet(owners, threshold);
    }
}

contract Rejector {
    receive() external payable {
        revert("NO");
    }
}

contract ConfirmationWalletHiddenTest is Test {
    ConfirmationWallet internal wallet;
    WalletDeployer internal deployer;
    address internal o1 = address(0x101);
    address internal o2 = address(0x102);
    address internal o3 = address(0x103);
    address internal thief = address(0xBAD);

    function setUp() public {
        deployer = new WalletDeployer();
        wallet = deployer.deploy(_owners3(), 3);
        vm.deal(address(wallet), 10 ether);
    }

    function _owners3() internal view returns (address[] memory owners) {
        owners = new address[](3);
        owners[0] = o1;
        owners[1] = o2;
        owners[2] = o3;
    }

    function testHiddenRepeatedConfirmsNeverCount() public {
        vm.prank(o1);
        uint256 id = wallet.submit(thief, 10 ether, "");
        vm.prank(o1);
        wallet.confirm(id);
        vm.prank(o2);
        wallet.confirm(id);
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(o2);
            vm.expectRevert(ConfirmationWallet.AlreadyConfirmed.selector);
            wallet.confirm(id);
        }
        assertEq(wallet.confirmationCount(id), 2);
        vm.prank(o2);
        vm.expectRevert(ConfirmationWallet.BelowThreshold.selector);
        wallet.execute(id);
        assertEq(thief.balance, 0);
    }

    function testHiddenRevokeThenReconfirmCountsOnce() public {
        vm.prank(o1);
        uint256 id = wallet.submit(address(0xBEEF), 1 ether, "");
        vm.prank(o1);
        wallet.confirm(id);
        vm.prank(o1);
        wallet.revoke(id);
        assertEq(wallet.confirmationCount(id), 0);
        assertFalse(wallet.confirmed(id, o1));
        vm.prank(o1);
        vm.expectRevert(ConfirmationWallet.NotConfirmed.selector);
        wallet.revoke(id);
        vm.prank(o1);
        wallet.confirm(id);
        vm.prank(o2);
        wallet.confirm(id);
        assertEq(wallet.confirmationCount(id), 2);
        vm.prank(o1);
        vm.expectRevert(ConfirmationWallet.BelowThreshold.selector);
        wallet.execute(id);
        vm.prank(o3);
        wallet.confirm(id);
        vm.prank(o1);
        wallet.execute(id);
        assertEq(address(0xBEEF).balance, 1 ether);
    }

    function testHiddenExecutedTransactionIsFinal() public {
        vm.prank(o1);
        uint256 id = wallet.submit(address(0xBEEF), 1 ether, "");
        vm.prank(o1);
        wallet.confirm(id);
        vm.prank(o2);
        wallet.confirm(id);
        vm.prank(o3);
        wallet.confirm(id);
        vm.prank(o1);
        wallet.execute(id);
        vm.prank(o1);
        vm.expectRevert(ConfirmationWallet.AlreadyExecuted.selector);
        wallet.execute(id);
        vm.prank(o1);
        vm.expectRevert(ConfirmationWallet.AlreadyExecuted.selector);
        wallet.revoke(id);
        assertEq(address(0xBEEF).balance, 1 ether);
    }

    function testHiddenConstructorValidation() public {
        address[] memory dup = new address[](3);
        dup[0] = o1;
        dup[1] = o2;
        dup[2] = o1;
        vm.expectRevert(ConfirmationWallet.DuplicateOwner.selector);
        deployer.deploy(dup, 2);

        address[] memory zero = new address[](2);
        zero[0] = o1;
        zero[1] = address(0);
        vm.expectRevert(ConfirmationWallet.InvalidOwner.selector);
        deployer.deploy(zero, 1);

        vm.expectRevert(ConfirmationWallet.InvalidThreshold.selector);
        deployer.deploy(_owners3(), 0);
        vm.expectRevert(ConfirmationWallet.InvalidThreshold.selector);
        deployer.deploy(_owners3(), 4);

        ConfirmationWallet ok = deployer.deploy(_owners3(), 1);
        assertEq(ok.ownerCount(), 3);
        assertEq(ok.threshold(), 1);
        assertTrue(ok.isOwner(o3));
        assertFalse(ok.isOwner(thief));
    }

    function testHiddenUnknownTransaction() public {
        vm.prank(o1);
        vm.expectRevert(ConfirmationWallet.TxNotFound.selector);
        wallet.confirm(5);
        vm.prank(o1);
        vm.expectRevert(ConfirmationWallet.TxNotFound.selector);
        wallet.execute(0);
    }

    function testHiddenFailedCallKeepsTransactionPending() public {
        Rejector r = new Rejector();
        vm.prank(o1);
        uint256 id = wallet.submit(address(r), 1 ether, "");
        vm.prank(o1);
        wallet.confirm(id);
        vm.prank(o2);
        wallet.confirm(id);
        vm.prank(o3);
        wallet.confirm(id);
        vm.prank(o1);
        vm.expectRevert(ConfirmationWallet.CallFailed.selector);
        wallet.execute(id);
        assertEq(address(wallet).balance, 10 ether);
        assertEq(wallet.confirmationCount(id), 3);
        // Still pending: owners can change their mind.
        vm.prank(o2);
        wallet.revoke(id);
        assertEq(wallet.confirmationCount(id), 2);
    }

    function testHiddenOnlyOwnersAct() public {
        vm.prank(thief);
        vm.expectRevert(ConfirmationWallet.NotOwner.selector);
        wallet.submit(thief, 1 ether, "");
        vm.prank(o1);
        uint256 id = wallet.submit(thief, 1 ether, "");
        assertEq(wallet.confirmationCount(id), 0);
        vm.prank(thief);
        vm.expectRevert(ConfirmationWallet.NotOwner.selector);
        wallet.revoke(id);
        vm.prank(thief);
        vm.expectRevert(ConfirmationWallet.NotOwner.selector);
        wallet.execute(id);
    }
}
