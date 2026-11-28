// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RewardDistributor.sol";

/// During the reward payment of claim(), walks into the vault, whose hook pays again.
contract ClaimThenExit {
    StakeVault public immutable vault;
    RewardDistributor public immutable distributor;
    bool internal armed;

    constructor(StakeVault _vault) {
        vault = _vault;
        distributor = _vault.distributor();
    }

    function stake() external payable {
        vault.deposit{value: msg.value}();
    }

    function attack() external {
        armed = true;
        distributor.claim();
        armed = false;
    }

    receive() external payable {
        if (armed && msg.sender == address(distributor)) {
            armed = false;
            try vault.withdraw(vault.balanceOf(address(this))) {} catch {}
        }
    }
}

contract RewardDistributorTest is Test {
    StakeVault public vault;
    RewardDistributor public distributor;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        vault = new StakeVault();
        distributor = vault.distributor();
        vm.deal(alice, 30 ether);
        vm.deal(bob, 10 ether);
        vm.prank(alice);
        vault.deposit{value: 30 ether}();
    }

    function testRewardsSplitProRata() public {
        vm.prank(bob);
        vault.deposit{value: 10 ether}();
        distributor.fund{value: 4 ether}();
        assertEq(distributor.pending(alice), 3 ether);
        assertEq(distributor.pending(bob), 1 ether);

        vm.prank(bob);
        distributor.claim();
        assertEq(bob.balance, 1 ether);
        assertEq(distributor.pending(bob), 0);
        assertEq(distributor.pending(alice), 3 ether);
    }

    function testWithdrawPaysStakeAndRewards() public {
        distributor.fund{value: 3 ether}();
        vm.prank(alice);
        vault.withdraw(30 ether);
        assertEq(alice.balance, 33 ether);
        assertEq(vault.totalStaked(), 0);
        assertEq(address(distributor).balance, 0);
    }

    function testClaimIsNotPaidTwiceWithoutNewFunding() public {
        distributor.fund{value: 3 ether}();
        vm.prank(alice);
        distributor.claim();
        vm.prank(alice);
        distributor.claim();
        assertEq(alice.balance, 3 ether);
    }

    function testReentrantClaimThroughVaultIsNotPaidTwice() public {
        ClaimThenExit attacker = new ClaimThenExit(vault);
        attacker.stake{value: 10 ether}();
        distributor.fund{value: 4 ether}(); // attacker is owed 1 ether, alice 3 ether

        attacker.attack();

        // Whatever the attacker withdrew of its own stake, its reward is at most 1 ether.
        uint256 stakeLeft = vault.balanceOf(address(attacker));
        assertLe(address(attacker).balance + stakeLeft, 11 ether);

        // The distributor can still pay alice in full.
        vm.prank(alice);
        distributor.claim();
        assertEq(alice.balance, 3 ether);
    }
}
