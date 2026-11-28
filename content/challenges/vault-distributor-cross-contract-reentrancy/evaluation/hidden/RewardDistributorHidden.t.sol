// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RewardDistributor.sol";

/// Starts in the vault and re-enters the distributor from the settle() payment.
contract ExitThenClaim {
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

    function attack(uint256 amount) external {
        armed = true;
        vault.withdraw(amount);
        armed = false;
    }

    receive() external payable {
        if (armed && msg.sender == address(distributor)) {
            armed = false;
            try distributor.claim() {} catch {}
        }
    }
}

/// Re-enters through deposit() while claim() is paying.
contract ClaimThenDeposit {
    StakeVault public immutable vault;
    RewardDistributor public immutable distributor;
    uint256 internal rounds;

    constructor(StakeVault _vault) {
        vault = _vault;
        distributor = _vault.distributor();
    }

    function stake() external payable {
        vault.deposit{value: msg.value}();
    }

    function attack() external {
        rounds = 3;
        distributor.claim();
        rounds = 0;
    }

    receive() external payable {
        if (rounds != 0 && msg.sender == address(distributor)) {
            rounds--;
            try vault.deposit{value: 1 wei}() {} catch {}
        }
    }
}

contract RewardDistributorHiddenTest is Test {
    StakeVault public vault;
    RewardDistributor public distributor;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA201);

    function setUp() public {
        vault = new StakeVault();
        distributor = vault.distributor();
        vm.deal(alice, 30 ether);
        vm.deal(bob, 10 ether);
        vm.deal(carol, 40 ether);
        vm.prank(alice);
        vault.deposit{value: 30 ether}();
    }

    function testHiddenSettlePaymentCannotBeClaimedAgain() public {
        ExitThenClaim attacker = new ExitThenClaim(vault);
        attacker.stake{value: 10 ether}();
        distributor.fund{value: 4 ether}();

        attacker.attack(4 ether);

        uint256 stakeLeft = vault.balanceOf(address(attacker));
        assertEq(stakeLeft, 6 ether);
        assertEq(address(attacker).balance, 5 ether); // 4 stake + 1 reward
        assertEq(distributor.pending(address(attacker)), 0);
        assertEq(address(distributor).balance, 3 ether);

        vm.prank(alice);
        vault.withdraw(30 ether);
        assertEq(alice.balance, 33 ether);
    }

    function testHiddenDepositDuringClaimDoesNotRepeatPayout() public {
        ClaimThenDeposit attacker = new ClaimThenDeposit(vault);
        attacker.stake{value: 10 ether}();
        distributor.fund{value: 4 ether}();

        attacker.attack();

        uint256 staked = vault.balanceOf(address(attacker));
        assertLe(address(attacker).balance + staked, 11 ether);
        assertGe(address(distributor).balance, 3 ether);
        assertEq(distributor.pending(alice), 3 ether);
    }

    function testHiddenLateStakerEarnsOnlyFutureRewards() public {
        vm.prank(bob);
        vault.deposit{value: 10 ether}();
        distributor.fund{value: 4 ether}();

        vm.prank(carol);
        vault.deposit{value: 40 ether}();
        assertEq(distributor.pending(carol), 0);

        distributor.fund{value: 8 ether}(); // 80 staked: alice 3, bob 1, carol 4
        assertEq(distributor.pending(alice), 6 ether);
        assertEq(distributor.pending(bob), 2 ether);
        assertEq(distributor.pending(carol), 4 ether);

        vm.prank(alice);
        vault.withdraw(30 ether);
        vm.prank(bob);
        distributor.claim();
        vm.prank(carol);
        vault.withdraw(10 ether);
        assertEq(alice.balance, 36 ether);
        assertEq(bob.balance, 2 ether);
        assertEq(carol.balance, 14 ether);
        assertEq(address(distributor).balance, 0);
        assertEq(distributor.pending(carol), 0);
    }

    function testHiddenTopUpSettlesOldStakeFirst() public {
        vm.deal(alice, 10 ether);
        distributor.fund{value: 3 ether}();
        vm.prank(alice);
        vault.deposit{value: 10 ether}(); // pays the 3 ether earned on the first 30
        assertEq(alice.balance, 3 ether);
        assertEq(distributor.pending(alice), 0);

        distributor.fund{value: 4 ether}();
        assertEq(distributor.pending(alice), 4 ether);
    }

    function testHiddenHooksAreVaultOnly() public {
        distributor.fund{value: 3 ether}();
        vm.expectRevert(RewardDistributor.NotVault.selector);
        vm.prank(bob);
        distributor.settle(alice);
        assertEq(alice.balance, 0);
        assertEq(distributor.pending(alice), 3 ether);
    }

    function testHiddenSyncIsVaultOnly() public {
        distributor.fund{value: 3 ether}();
        vm.expectRevert(RewardDistributor.NotVault.selector);
        vm.prank(alice);
        distributor.sync(alice);
        assertEq(distributor.pending(alice), 3 ether);
    }

    function testHiddenFundingRequiresStake() public {
        vm.prank(alice);
        vault.withdraw(30 ether);
        vm.expectRevert(RewardDistributor.NothingStaked.selector);
        distributor.fund{value: 1 ether}();
        assertEq(address(distributor).balance, 0);
    }
}
