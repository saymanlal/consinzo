// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LimitedMint.sol";

/// Honest contract wallet that simply accepts tokens.
contract HonestReceiver is IERC721Receiver {
    function buy(LimitedMint nft, uint256 quantity) external payable {
        nft.mint{value: msg.value}(quantity);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// Re-enters mint() from the safe-mint callback, one token at a time.
contract GreedyMinter is IERC721Receiver {
    LimitedMint public immutable nft;
    uint256 public reentries;

    constructor(LimitedMint _nft) {
        nft = _nft;
    }

    function attack() external payable {
        nft.mint{value: 0.1 ether}(1);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        if (reentries < 4) {
            reentries++;
            try nft.mint{value: 0.1 ether}(1) {} catch {}
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract LimitedMintTest is Test {
    LimitedMint public nft;
    address public alice = address(0xA11CE);

    function setUp() public {
        nft = new LimitedMint();
        vm.deal(alice, 1 ether);
    }

    function testEoaMintsUpToLimit() public {
        vm.prank(alice);
        nft.mint{value: 0.2 ether}(2);
        assertEq(nft.balanceOf(alice), 2);
        assertEq(nft.mintedBy(alice), 2);
        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.ownerOf(2), alice);
        assertEq(nft.totalSupply(), 2);
    }

    function testWalletLimitEnforcedAcrossCalls() public {
        vm.prank(alice);
        nft.mint{value: 0.1 ether}(1);
        vm.prank(alice);
        nft.mint{value: 0.1 ether}(1);
        vm.expectRevert(LimitedMint.WalletLimitExceeded.selector);
        vm.prank(alice);
        nft.mint{value: 0.1 ether}(1);
    }

    function testWrongPaymentReverts() public {
        vm.expectRevert(LimitedMint.WrongPayment.selector);
        vm.prank(alice);
        nft.mint{value: 0.1 ether}(2);
    }

    function testContractReceiverCanMint() public {
        HonestReceiver wallet = new HonestReceiver();
        wallet.buy{value: 0.2 ether}(nft, 2);
        assertEq(nft.balanceOf(address(wallet)), 2);
        assertEq(nft.mintedBy(address(wallet)), 2);
    }

    function testReentrantMintCannotExceedWalletLimit() public {
        GreedyMinter attacker = new GreedyMinter(nft);
        attacker.attack{value: 1 ether}();
        assertLe(nft.balanceOf(address(attacker)), 2);
        assertLe(nft.mintedBy(address(attacker)), 2);
        assertEq(nft.mintedBy(address(attacker)), nft.balanceOf(address(attacker)));
    }
}
