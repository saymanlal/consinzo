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

contract ConfirmationWalletTest is Test {
    ConfirmationWallet internal wallet;
    address internal o1 = address(0x101);
    address internal o2 = address(0x102);
    address internal o3 = address(0x103);
    address internal thief = address(0xBAD);

    function setUp() public {
        address[] memory owners = new address[](3);
        owners[0] = o1;
        owners[1] = o2;
        owners[2] = o3;
        wallet = new ConfirmationWallet(owners, 2);
        vm.deal(address(wallet), 10 ether);
    }

    function testSingleOwnerCannotReachThresholdAlone() public {
        vm.startPrank(o1);
        uint256 id = wallet.submit(thief, 10 ether, "");
        wallet.confirm(id);
        vm.expectRevert(ConfirmationWallet.AlreadyConfirmed.selector);
        wallet.confirm(id);
        assertEq(wallet.confirmationCount(id), 1);
        vm.expectRevert(ConfirmationWallet.BelowThreshold.selector);
        wallet.execute(id);
        vm.stopPrank();
        assertEq(address(wallet).balance, 10 ether);
        assertEq(thief.balance, 0);
    }

    function testTwoDistinctOwnersExecute() public {
        vm.prank(o1);
        uint256 id = wallet.submit(address(0xBEEF), 1 ether, "");
        vm.prank(o1);
        wallet.confirm(id);
        vm.prank(o2);
        wallet.confirm(id);
        assertEq(wallet.confirmationCount(id), 2);
        vm.prank(o3);
        wallet.execute(id);
        assertEq(address(0xBEEF).balance, 1 ether);
    }

    function testDuplicateOwnersRejectedAtDeployment() public {
        WalletDeployer d = new WalletDeployer();
        address[] memory owners = new address[](2);
        owners[0] = o1;
        owners[1] = o1;
        vm.expectRevert(ConfirmationWallet.DuplicateOwner.selector);
        d.deploy(owners, 2);
    }

    function testNonOwnerCannotConfirm() public {
        vm.prank(o1);
        uint256 id = wallet.submit(thief, 1 ether, "");
        vm.prank(thief);
        vm.expectRevert(ConfirmationWallet.NotOwner.selector);
        wallet.confirm(id);
    }
}
