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

contract EpochVaultTest is Test {
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

    function testDepositIsQueuedUntilRoll() public {
        _deposit(alice, 1000 ether);
        assertEq(vault.totalPending(), 1000 ether);
        assertEq(vault.shareBalanceOf(alice), 0);
        assertEq(vault.totalShares(), 0);
        (uint256 amount, uint256 ep) = vault.pendingDeposits(alice);
        assertEq(amount, 1000 ether);
        assertEq(ep, 1);

        vault.roll(0, 0);
        assertEq(vault.epoch(), 2);
        assertEq(vault.pricePerShare(1), 1 ether);
        assertEq(vault.totalShares(), 1000 ether);
        assertEq(vault.lockedAssets(), 1000 ether);
        assertEq(vault.totalPending(), 0);
        assertEq(vault.shareBalanceOf(alice), 1000 ether);
        assertEq(vault.shares(alice), 0); // not redeemed yet
        vm.prank(alice);
        vault.redeem();
        assertEq(vault.shares(alice), 1000 ether);
        _assertBuckets();
    }

    function testPremiumGoesToExistingSharesOnly() public {
        _deposit(alice, 1000 ether);
        vault.roll(0, 0);
        _deposit(bob, 500 ether); // waits during epoch 2
        vault.roll(250 ether, 0);
        assertEq(vault.pricePerShare(2), 1.25 ether);
        assertEq(vault.shareBalanceOf(bob), 400 ether);
        assertEq(vault.totalShares(), 1400 ether);
        assertEq(vault.lockedAssets(), 1750 ether);
        _assertBuckets();
    }

    function testWithdrawIsPaidAtTheSettledPrice() public {
        _deposit(alice, 1000 ether);
        vault.roll(0, 0);
        _deposit(bob, 500 ether);
        vault.roll(250 ether, 0);

        _request(alice, 400 ether);
        assertEq(vault.queuedShares(), 400 ether);
        assertEq(vault.shareBalanceOf(alice), 600 ether);
        vm.prank(alice);
        vm.expectRevert(EpochVault.WithdrawalNotReady.selector);
        vault.completeWithdraw();

        uint256 keeperBefore = token.balanceOf(address(this));
        vault.roll(0, 350 ether); // options expire in the money: the vault pays 350
        assertEq(token.balanceOf(address(this)), keeperBefore + 350 ether);
        assertEq(vault.pricePerShare(3), 1 ether);
        assertEq(vault.withdrawalReserve(), 400 ether);
        assertEq(vault.lockedAssets(), 1000 ether);
        assertEq(vault.totalShares(), 1000 ether);

        assertEq(_complete(alice), 400 ether);
        assertEq(token.balanceOf(alice), 9400 ether);
        assertEq(vault.withdrawalReserve(), 0);
        _assertBuckets();
    }

    function testCancelDepositBeforeRoll() public {
        _deposit(alice, 1000 ether);
        vm.prank(alice);
        vault.cancelDeposit(300 ether);
        assertEq(token.balanceOf(alice), 9300 ether);
        assertEq(vault.totalPending(), 700 ether);
        vault.roll(0, 0);
        vm.prank(alice);
        vm.expectRevert(EpochVault.InsufficientPending.selector);
        vault.cancelDeposit(1 ether);
        assertEq(vault.shareBalanceOf(alice), 700 ether);
    }

    function testOnlyOwnerRolls() public {
        vm.prank(alice);
        vm.expectRevert(EpochVault.NotOwner.selector);
        vault.roll(0, 0);
    }

    function testPayoutCannotWipeTheVault() public {
        _deposit(alice, 1000 ether);
        vault.roll(0, 0);
        vm.expectRevert(EpochVault.PayoutTooLarge.selector);
        vault.roll(100 ether, 1100 ether);
        // one wei left for 1000 shares would round the price to zero
        vm.expectRevert(EpochVault.PayoutTooLarge.selector);
        vault.roll(100 ether, 1100 ether - 1);
        vault.roll(100 ether, 1100 ether - 1000);
        assertEq(vault.pricePerShare(2), 1);
        assertEq(vault.lockedAssets(), 1000);
    }
}
