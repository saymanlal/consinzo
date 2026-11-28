// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SafeNFT.sol";

contract AcceptingReceiver is IERC721Receiver {
    uint256 public received;

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        received++;
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract NoHookContract {
    uint256 public value = 1;
}

contract SafeNFTTest is Test {
    SafeNFT public nft;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        nft = new SafeNFT();
        nft.safeMint(alice, 1);
    }

    function testSafeMintToEoa() public view {
        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.balanceOf(alice), 1);
    }

    function testSafeTransferToEoa() public {
        vm.prank(alice);
        nft.safeTransferFrom(alice, bob, 1);
        assertEq(nft.ownerOf(1), bob);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(bob), 1);
    }

    function testSafeTransferToAcceptingContract() public {
        AcceptingReceiver receiver = new AcceptingReceiver();
        vm.prank(alice);
        nft.safeTransferFrom(alice, address(receiver), 1);
        assertEq(nft.ownerOf(1), address(receiver));
        assertEq(receiver.received(), 1);
    }

    function testSafeTransferToContractWithoutHookReverts() public {
        NoHookContract target = new NoHookContract();
        vm.prank(alice);
        vm.expectRevert(SafeNFT.UnsafeRecipient.selector);
        nft.safeTransferFrom(alice, address(target), 1);
        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.balanceOf(address(target)), 0);
    }

    function testSafeMintToAcceptingContract() public {
        AcceptingReceiver receiver = new AcceptingReceiver();
        nft.safeMint(address(receiver), 2);
        assertEq(nft.ownerOf(2), address(receiver));
        assertEq(receiver.received(), 1);
    }
}
