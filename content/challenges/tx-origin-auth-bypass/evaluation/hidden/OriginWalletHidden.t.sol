// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/OriginWallet.sol";

contract OriginWalletHiddenTest is Test {
    OriginWallet public wallet;
    function setUp() public { wallet = new OriginWallet{value: 2 ether}(); }
    function testHiddenNonOwnerReverts() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert();
        wallet.transferTo(payable(address(0xBEEF)), 1 ether);
    }
}