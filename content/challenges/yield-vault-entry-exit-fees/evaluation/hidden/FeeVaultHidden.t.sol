// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FeeVault.sol";

contract MockERC20 {
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
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
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract FeeVaultHiddenTest is Test {
    MockERC20 public token;
    FeeVault public vault;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA201);
    address public treasury = address(0xFEE);

    function setUp() public {
        token = new MockERC20();
        vault = new FeeVault(address(token), 100, 50, treasury);
        address[3] memory users = [alice, bob, carol];
        for (uint256 i = 0; i < 3; i++) {
            token.mint(users[i], 10_000 ether);
            vm.prank(users[i]);
            token.approve(address(vault), type(uint256).max);
        }
        token.mint(address(this), 100_000 ether);
        token.approve(address(vault), type(uint256).max);
    }

    function deploy(uint256 inBps, uint256 outBps, address recipient) external returns (FeeVault) {
        return new FeeVault(address(token), inBps, outBps, recipient);
    }

    function testHiddenConstructorValidation() public {
        vm.expectRevert(FeeVault.FeeTooHigh.selector);
        this.deploy(1001, 0, treasury);
        vm.expectRevert(FeeVault.FeeTooHigh.selector);
        this.deploy(0, 1001, treasury);
        vm.expectRevert(FeeVault.ZeroAddress.selector);
        this.deploy(10, 10, address(0));
        FeeVault v = this.deploy(1000, 1000, treasury);
        assertEq(v.depositFeeBps(), 1000);
        assertEq(v.withdrawFeeBps(), 1000);
        assertEq(v.feeRecipient(), treasury);
    }

    function testHiddenDirectTransfersAreIgnored() public {
        vm.prank(alice);
        vault.deposit(1_000 ether);
        token.transfer(address(vault), 5_000 ether); // donation outside addYield
        assertEq(vault.totalAssets(), 990 ether);
        assertEq(vault.convertToAssets(990 ether), 990 ether);
        vm.prank(bob);
        assertEq(vault.deposit(1_000 ether), 990 ether);
        vm.prank(alice);
        assertEq(vault.redeem(990 ether), 990 ether - 4.95 ether);
    }

    function testHiddenInflationAttemptHitsZeroShares() public {
        vm.prank(alice);
        assertEq(vault.deposit(1), 1); // fee rounds to zero, one share
        assertEq(token.balanceOf(treasury), 0);
        vm.prank(alice);
        vault.addYield(1_000 ether);
        // bob's 500 would buy 495e18 * 1 / (1000e18 + 1) = 0 shares
        vm.prank(bob);
        vm.expectRevert(FeeVault.ZeroShares.selector);
        vault.deposit(500 ether);
        assertEq(token.balanceOf(bob), 10_000 ether);
        // a deposit large enough for at least one share is priced fairly
        vm.prank(bob);
        assertEq(vault.deposit(5_000 ether), 4);
    }

    function testHiddenZeroFeeVault() public {
        FeeVault free = this.deploy(0, 0, treasury);
        vm.prank(alice);
        token.approve(address(free), type(uint256).max);
        vm.prank(alice);
        assertEq(free.deposit(123 ether), 123 ether);
        vm.prank(alice);
        assertEq(free.redeem(123 ether), 123 ether);
        assertEq(token.balanceOf(treasury), 0);
        assertEq(token.balanceOf(alice), 10_000 ether);
    }

    function testHiddenYieldRulesAndZeroAmounts() public {
        vm.expectRevert(FeeVault.NoShareholders.selector);
        vault.addYield(1 ether);
        vm.prank(alice);
        vm.expectRevert(FeeVault.ZeroAmount.selector);
        vault.deposit(0);
        vm.prank(alice);
        vault.deposit(100 ether);
        vm.expectRevert(FeeVault.ZeroAmount.selector);
        vault.addYield(0);
        vm.prank(alice);
        vm.expectRevert(FeeVault.ZeroAmount.selector);
        vault.redeem(0);
        vm.prank(bob);
        vm.expectRevert(FeeVault.InsufficientShares.selector);
        vault.redeem(1);
    }

    function testHiddenMultiUserSolvency() public {
        vm.prank(alice);
        vault.deposit(1_000 ether + 7);
        vault.addYield(33 ether + 1);
        vm.prank(bob);
        vault.deposit(777 ether + 3);
        vault.addYield(0.5 ether);
        vm.prank(carol);
        vault.deposit(4_321 ether + 11);
        assertGe(token.balanceOf(address(vault)), vault.totalAssets());

        uint256 aliceShares = vault.balanceOf(alice);
        vm.prank(alice);
        vault.redeem(aliceShares / 3);
        assertGe(token.balanceOf(address(vault)), vault.totalAssets());
        vault.addYield(10 ether);

        uint256 a = vault.balanceOf(alice);
        uint256 b = vault.balanceOf(bob);
        uint256 c = vault.balanceOf(carol);
        vm.prank(carol);
        vault.redeem(c);
        vm.prank(alice);
        vault.redeem(a);
        vm.prank(bob);
        vault.redeem(b);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);
        assertEq(token.balanceOf(address(vault)), 0);
        // every token is accounted for: users, treasury, and this contract's remaining funds
        uint256 total = token.balanceOf(alice) + token.balanceOf(bob) + token.balanceOf(carol) +
            token.balanceOf(treasury) + token.balanceOf(address(this));
        assertEq(total, 130_000 ether);
    }

    function testHiddenFeeMathAfterYield() public {
        vm.prank(alice);
        vault.deposit(2_000 ether); // 1980 shares, 1980 assets
        vault.addYield(990 ether); // price 1.5
        vm.prank(bob);
        uint256 shares = vault.deposit(300 ether); // net 297 -> 198 shares
        assertEq(shares, 198 ether);
        uint256 treasuryBefore = token.balanceOf(treasury);
        vm.prank(bob);
        uint256 out = vault.redeem(198 ether); // gross 297, fee 1.485
        assertEq(out, 295.515 ether);
        assertEq(token.balanceOf(treasury) - treasuryBefore, 1.485 ether);
        // alice's position is unaffected by bob's round trip
        assertEq(vault.convertToAssets(1980 ether), 2_970 ether);
        assertEq(vault.totalAssets(), 2_970 ether);
    }
}
