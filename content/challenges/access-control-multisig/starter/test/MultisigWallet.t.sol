// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MultisigWallet.sol";

contract MultisigWalletTest is Test {
    MultisigWallet public wallet;
    address public owner1 = address(0x101);
    address public owner2 = address(0x102);
    address public owner3 = address(0x103);
    address public recipient = address(0x999);

    function setUp() public {
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
        wallet = new MultisigWallet(owners, 2);
        vm.deal(address(wallet), 5 ether);
    }

    function testSubmitConfirmExecute() public {
        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(recipient, 2 ether, "");
        vm.prank(owner1);
        wallet.confirmTransaction(txId);
        vm.prank(owner2);
        wallet.confirmTransaction(txId);

        uint256 beforeBal = recipient.balance;
        vm.prank(owner1);
        wallet.executeTransaction(txId);
        assertEq(recipient.balance, beforeBal + 2 ether);
    }

    function testRevokeBlocksExecution() public {
        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(recipient, 1 ether, "");
        vm.prank(owner1);
        wallet.confirmTransaction(txId);
        vm.prank(owner2);
        wallet.confirmTransaction(txId);
        vm.prank(owner2);
        wallet.revokeConfirmation(txId);

        vm.prank(owner1);
        vm.expectRevert();
        wallet.executeTransaction(txId);
    }
}
