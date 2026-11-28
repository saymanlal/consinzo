// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RewardToken.sol";

contract MintProxy {
    function tryMint(RewardToken token, uint256 amount) external returns (bool ok) {
        (ok, ) = address(token).call(abi.encodeCall(RewardToken.mint, (address(this), amount)));
    }
}

contract RewardTokenHiddenTest is Test {
    RewardToken public token;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public mallory = address(0xBAD);

    function setUp() public {
        token = new RewardToken();
        token.mint(alice, 1_000);
    }

    function testHiddenHolderCannotMint() public {
        // Holding tokens grants no privilege.
        vm.prank(alice);
        vm.expectRevert(RewardToken.NotOwner.selector);
        token.mint(alice, 1);
        assertEq(token.totalSupply(), 1_000);
    }

    function testHiddenStrangerCannotMintToThirdParty() public {
        vm.prank(mallory);
        vm.expectRevert(RewardToken.NotOwner.selector);
        token.mint(bob, 7);
        assertEq(token.balanceOf(bob), 0);
    }

    function testHiddenContractCallerCannotMint() public {
        MintProxy proxy = new MintProxy();
        assertFalse(proxy.tryMint(token, 5_000));
        assertEq(token.balanceOf(address(proxy)), 0);
        assertEq(token.totalSupply(), 1_000);
    }

    function testHiddenMintingRightsFollowOwnership() public {
        token.transferOwnership(bob);
        assertEq(token.owner(), bob);

        // The previous owner (this test contract) has lost the right to mint.
        vm.expectRevert(RewardToken.NotOwner.selector);
        token.mint(address(this), 1);

        vm.prank(bob);
        token.mint(bob, 250);
        assertEq(token.balanceOf(bob), 250);
        assertEq(token.totalSupply(), 1_250);
    }

    function testHiddenZeroAddressMintStillRejected() public {
        vm.expectRevert(RewardToken.ZeroAddress.selector);
        token.mint(address(0), 1);
        assertEq(token.totalSupply(), 1_000);
    }

    function testHiddenOwnerMintsAccumulate() public {
        token.mint(alice, 1);
        token.mint(bob, 2);
        token.mint(alice, 3);
        assertEq(token.balanceOf(alice), 1_004);
        assertEq(token.balanceOf(bob), 2);
        assertEq(token.totalSupply(), 1_006);
    }
}
