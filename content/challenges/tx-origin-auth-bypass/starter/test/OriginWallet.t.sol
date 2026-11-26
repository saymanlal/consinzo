// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/OriginWallet.sol";

contract PhishingForwarder {
    OriginWallet public wallet;
    constructor(OriginWallet w) { wallet = w; }
    function claimBonus(address payable attacker) external {
        wallet.transferTo(attacker, address(wallet).balance);
    }
}

contract OriginWalletTest is Test {
    OriginWallet public wallet;
    address public owner = address(0x101);
    address payable public attacker = payable(address(0xBAD));

    function setUp() public {
        vm.deal(owner, 10 ether);
        vm.prank(owner);
        wallet = new OriginWallet{value: 5 ether}();
    }

    function testOwnerDirectTransferWorks() public {
        vm.prank(owner);
        wallet.transferTo(payable(owner), 1 ether);
        assertEq(address(wallet).balance, 4 ether);
    }

    function testPhishingContractBlocked() public {
        PhishingForwarder phish = new PhishingForwarder(wallet);
        vm.prank(owner);
        vm.expectRevert();
        phish.claimBonus(attacker);
        assertEq(address(wallet).balance, 5 ether);
    }
}