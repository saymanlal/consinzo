// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MultisigWallet.sol";

contract MultisigWalletHiddenTest is Test {
    MultisigWallet public wallet;
    address public owner1 = address(0x101);
    address public owner2 = address(0x102);
    address public attacker = address(0xBAD);
    address public recipient = address(0x999);

    function setUp() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;
        wallet = new MultisigWallet(owners, 2);
        vm.deal(address(wallet), 4 ether);
    }

    function testHiddenNonOwnerRejected() public {
        vm.prank(attacker);
        vm.expectRevert();
        wallet.submitTransaction(attacker, 1 ether, "");
    }

    function testHiddenCannotDoubleConfirmOrDoubleExecute() public {
        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(recipient, 1 ether, "");
        vm.prank(owner1);
        wallet.confirmTransaction(txId);

        vm.prank(owner1);
        vm.expectRevert();
        wallet.confirmTransaction(txId);

        vm.prank(owner2);
        wallet.confirmTransaction(txId);
        vm.prank(owner1);
        wallet.executeTransaction(txId);

        vm.prank(owner1);
        vm.expectRevert();
        wallet.executeTransaction(txId);
    }
}
