// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LimitedMint.sol";

/// Re-enters with the largest quantity that still passes the up-front checks.
contract CapBreaker is IERC721Receiver {
    LimitedMint public immutable nft;

    constructor(LimitedMint _nft) {
        nft = _nft;
    }

    function attack() external payable {
        nft.mint{value: 0.2 ether}(2);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        if (address(this).balance >= 0.2 ether) {
            try nft.mint{value: 0.2 ether}(2) {} catch {}
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract NoCallback {
    function buy(LimitedMint nft) external payable {
        nft.mint{value: msg.value}(1);
    }
}

contract WrongSelector {
    function buy(LimitedMint nft) external payable {
        nft.mint{value: msg.value}(1);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return bytes4(0xdeadbeef);
    }
}

contract LimitedMintHiddenTest is Test {
    LimitedMint public nft;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        nft = new LimitedMint();
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
    }

    function testHiddenReentrancyCannotBreakSupplyCapOrLimit() public {
        CapBreaker attacker = new CapBreaker(nft);
        attacker.attack{value: 5 ether}();
        assertLe(nft.totalSupply(), 10);
        assertLe(nft.balanceOf(address(attacker)), 2);
        // Every wei held by the sale corresponds to a minted token.
        assertEq(address(nft).balance, nft.totalSupply() * 0.1 ether);
    }

    function testHiddenLimitCountsMintsNotHoldings() public {
        vm.prank(alice);
        nft.mint{value: 0.2 ether}(2);
        vm.prank(alice);
        nft.transferFrom(alice, bob, 1);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.ownerOf(1), bob);

        vm.expectRevert(LimitedMint.WalletLimitExceeded.selector);
        vm.prank(alice);
        nft.mint{value: 0.1 ether}(1);

        // Receiving a token does not consume bob's own allowance.
        vm.prank(bob);
        nft.mint{value: 0.2 ether}(2);
        assertEq(nft.balanceOf(bob), 3);
        assertEq(nft.mintedBy(bob), 2);
    }

    function testHiddenSingleCallOverLimitReverts() public {
        vm.expectRevert(LimitedMint.WalletLimitExceeded.selector);
        vm.prank(alice);
        nft.mint{value: 0.3 ether}(3);
    }

    function testHiddenZeroQuantityReverts() public {
        vm.expectRevert(LimitedMint.ZeroQuantity.selector);
        vm.prank(alice);
        nft.mint(0);
    }

    function testHiddenUnsafeRecipientsRejected() public {
        NoCallback a = new NoCallback();
        vm.expectRevert();
        a.buy{value: 0.1 ether}(nft);

        WrongSelector b = new WrongSelector();
        vm.expectRevert();
        b.buy{value: 0.1 ether}(nft);

        assertEq(nft.totalSupply(), 0);
    }

    function testHiddenSoldOutAfterTenTokens() public {
        for (uint160 i = 1; i <= 5; i++) {
            address buyer = address(0x1000 + i);
            vm.deal(buyer, 1 ether);
            vm.prank(buyer);
            nft.mint{value: 0.2 ether}(2);
        }
        assertEq(nft.totalSupply(), 10);
        assertEq(nft.ownerOf(10), address(0x1005));

        vm.expectRevert(LimitedMint.SoldOut.selector);
        vm.prank(alice);
        nft.mint{value: 0.1 ether}(1);
    }

    function testHiddenOnlyOwnerWithdrawsProceeds() public {
        vm.prank(alice);
        nft.mint{value: 0.2 ether}(2);

        vm.expectRevert(LimitedMint.NotOwner.selector);
        vm.prank(alice);
        nft.withdrawProceeds();
        assertEq(address(nft).balance, 0.2 ether);
    }
}
