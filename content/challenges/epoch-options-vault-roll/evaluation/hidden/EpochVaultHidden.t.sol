// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/EpochVault.sol";

contract MockERC20 {
    string public name;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory name_) {
        name = name_;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function burn(address from, uint256 amount) external {
        totalSupply -= amount;
        balanceOf[from] -= amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract EpochVaultHiddenTest is Test {
    EpochVault public vault;
    MockERC20 public token;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA201);

    function setUp() public {
        token = new MockERC20("ASSET");
        vault = new EpochVault(IAsset(address(token)));
        token.mint(address(this), 1_000_000 ether); // keeper pays premiums
        token.approve(address(vault), type(uint256).max);
        address[3] memory users = [alice, bob, carol];
        for (uint256 i = 0; i < 3; i++) {
            token.mint(users[i], 10_000 ether);
            vm.prank(users[i]);
            token.approve(address(vault), type(uint256).max);
        }
    }

    function _deposit(address who, uint256 amount) internal {
        vm.prank(who);
        vault.deposit(amount);
    }

    function _request(address who, uint256 shareAmount) internal {
        vm.prank(who);
        vault.requestWithdraw(shareAmount);
    }

    function _complete(address who) internal returns (uint256 assets) {
        vm.prank(who);
        assets = vault.completeWithdraw();
    }

    function _assertBuckets() internal view {
        assertEq(
            token.balanceOf(address(vault)),
            vault.lockedAssets() + vault.totalPending() + vault.withdrawalReserve()
        );
    }

    function testHiddenRoundingFavoursTheVault() public {
        _deposit(alice, 1000 ether);
        vault.roll(0, 0);
        _deposit(bob, 500 ether);
        vault.roll(100 ether, 0);
        assertEq(vault.pricePerShare(2), 1.1 ether);
        // 500 / 1.1 rounded down
        assertEq(vault.shareBalanceOf(bob), 454545454545454545454);
        assertEq(vault.totalShares(), 1454545454545454545454);
        _request(bob, 454545454545454545454);
        vault.roll(0, 0);
        assertEq(vault.pricePerShare(3), 1.1 ether);
        assertEq(_complete(bob), 500 ether - 1);
        assertEq(vault.lockedAssets(), 1100 ether + 1);
        assertEq(vault.totalShares(), 1000 ether);
        _assertBuckets();
    }

    function testHiddenQueuedSharesBearTheEpochLoss() public {
        _deposit(alice, 1000 ether);
        _deposit(bob, 1000 ether);
        vault.roll(0, 0);
        _request(alice, 1000 ether);
        _deposit(carol, 900 ether);
        vault.roll(0, 200 ether); // 10% loss on 2000
        assertEq(vault.pricePerShare(2), 0.9 ether);
        assertEq(_complete(alice), 900 ether);
        assertEq(vault.shareBalanceOf(carol), 1000 ether);
        assertEq(vault.shareBalanceOf(bob), 1000 ether);
        assertEq(vault.lockedAssets(), 1800 ether);
        _assertBuckets();
    }

    function testHiddenSecondDepositRedeemsTheFirst() public {
        _deposit(alice, 1000 ether);
        vault.roll(0, 0);
        _deposit(bob, 100 ether);
        vault.roll(1000 ether, 0); // price 2.0, bob gets 50 shares
        _deposit(bob, 300 ether); // new pending deposit in epoch 3
        assertEq(vault.shares(bob), 50 ether);
        (uint256 amount, uint256 ep) = vault.pendingDeposits(bob);
        assertEq(amount, 300 ether);
        assertEq(ep, 3);
        assertEq(vault.shareBalanceOf(bob), 50 ether);
        // only the epoch-3 part can be cancelled
        vm.prank(bob);
        vm.expectRevert(EpochVault.InsufficientPending.selector);
        vault.cancelDeposit(300 ether + 1);
        vm.prank(bob);
        vault.cancelDeposit(100 ether);
        vault.roll(0, 0);
        assertEq(vault.pricePerShare(3), 2 ether);
        assertEq(vault.shareBalanceOf(bob), 150 ether);
        _assertBuckets();
    }

    function testHiddenTwoDepositsInOneEpochAccumulate() public {
        _deposit(alice, 100 ether);
        _deposit(alice, 200 ether);
        (uint256 amount, ) = vault.pendingDeposits(alice);
        assertEq(amount, 300 ether);
        vault.roll(0, 0);
        assertEq(vault.shareBalanceOf(alice), 300 ether);
    }

    function testHiddenWithdrawRequestsAccumulateWithinAnEpoch() public {
        _deposit(alice, 1000 ether);
        vault.roll(0, 0);
        _request(alice, 100 ether);
        _request(alice, 200 ether);
        (uint256 queued, uint256 ep) = vault.withdrawals(alice);
        assertEq(queued, 300 ether);
        assertEq(ep, 2);
        assertEq(vault.queuedShares(), 300 ether);
        vm.prank(alice);
        vm.expectRevert(EpochVault.InsufficientShares.selector);
        vault.requestWithdraw(700 ether + 1);
        vault.roll(500 ether, 0); // price 1.5
        assertEq(_complete(alice), 450 ether);
        assertEq(vault.lockedAssets(), 1050 ether);
        vm.prank(alice);
        vm.expectRevert(EpochVault.NoWithdrawal.selector);
        vault.completeWithdraw();
    }

    function testHiddenUnclaimedWithdrawalBlocksNewRequest() public {
        _deposit(alice, 1000 ether);
        vault.roll(0, 0);
        _request(alice, 100 ether);
        vault.roll(0, 0);
        vm.prank(alice);
        vm.expectRevert(EpochVault.WithdrawalNotClaimed.selector);
        vault.requestWithdraw(100 ether);
        // the old request keeps its own epoch's price even if later epochs lose money
        vault.roll(0, 450 ether); // 900 -> 450: price 0.5 for epoch 3
        assertEq(vault.pricePerShare(3), 0.5 ether);
        assertEq(_complete(alice), 100 ether);
        _request(alice, 100 ether);
        vault.roll(0, 0);
        assertEq(_complete(alice), 50 ether);
        _assertBuckets();
    }

    function testHiddenReserveIsNotAtRisk() public {
        _deposit(alice, 1000 ether);
        _deposit(bob, 1000 ether);
        vault.roll(0, 0);
        _request(alice, 1000 ether);
        vault.roll(0, 0);
        assertEq(vault.withdrawalReserve(), 1000 ether);
        // the payout is limited by locked assets, not by the vault's whole balance
        vm.expectRevert(EpochVault.PayoutTooLarge.selector);
        vault.roll(0, 1000 ether);
        vault.roll(0, 999 ether);
        assertEq(vault.withdrawalReserve(), 1000 ether);
        assertEq(_complete(alice), 1000 ether);
        assertEq(vault.lockedAssets(), 1 ether);
        _assertBuckets();
    }

    function testHiddenEmptyVaultRolls() public {
        vm.expectRevert(EpochVault.NothingAtRisk.selector);
        vault.roll(1, 0);
        vm.expectRevert(EpochVault.NothingAtRisk.selector);
        vault.roll(0, 1);
        vault.roll(0, 0);
        vault.roll(0, 0);
        assertEq(vault.epoch(), 3);
        assertEq(vault.pricePerShare(1), 1 ether);
        assertEq(vault.pricePerShare(2), 1 ether);
        _deposit(alice, 10 ether);
        vault.roll(0, 0);
        assertEq(vault.shareBalanceOf(alice), 10 ether);
    }

    function testHiddenFullExitThenNewDepositors() public {
        _deposit(alice, 1000 ether);
        vault.roll(0, 0);
        _request(alice, 1000 ether);
        _deposit(bob, 300 ether);
        vault.roll(500 ether, 0);
        assertEq(_complete(alice), 1500 ether);
        assertEq(vault.totalShares(), 200 ether); // 300 / 1.5
        assertEq(vault.lockedAssets(), 300 ether);
        _request(bob, 200 ether);
        vault.roll(0, 0);
        assertEq(_complete(bob), 300 ether);
        assertEq(vault.totalShares(), 0);
        assertEq(token.balanceOf(address(vault)), 0);
    }

    function testHiddenInputValidation() public {
        vm.startPrank(alice);
        vm.expectRevert(EpochVault.ZeroAmount.selector);
        vault.deposit(0);
        vm.expectRevert(EpochVault.ZeroAmount.selector);
        vault.cancelDeposit(0);
        vm.expectRevert(EpochVault.ZeroAmount.selector);
        vault.requestWithdraw(0);
        vm.expectRevert(EpochVault.InsufficientPending.selector);
        vault.cancelDeposit(1);
        vm.expectRevert(EpochVault.NoWithdrawal.selector);
        vault.completeWithdraw();
        vault.deposit(5 ether);
        // a pending deposit is not withdrawable as shares before the roll
        vm.expectRevert(EpochVault.InsufficientShares.selector);
        vault.requestWithdraw(1);
        vault.redeem(); // nothing to redeem yet
        vm.stopPrank();
        assertEq(vault.shares(alice), 0);
        assertEq(vault.totalPending(), 5 ether);
    }

    function testHiddenRequestRedeemsPendingDeposit() public {
        _deposit(alice, 1000 ether);
        vault.roll(0, 0);
        _request(alice, 1000 ether); // shares were never redeemed explicitly
        (uint256 amount, ) = vault.pendingDeposits(alice);
        assertEq(amount, 0);
        assertEq(vault.shareBalanceOf(alice), 0);
        vault.roll(100 ether, 0);
        assertEq(_complete(alice), 1100 ether);
        assertEq(token.balanceOf(alice), 10_100 ether);
    }
}
