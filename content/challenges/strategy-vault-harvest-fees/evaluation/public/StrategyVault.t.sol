// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StrategyVault.sol";

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

contract MockStrategy {
    MockERC20 public token;
    address public vault;
    uint256 public haircutBps; // part of every withdrawal that is lost
    bool public lie; // report the requested amount even when less was sent

    constructor(MockERC20 token_) {
        token = token_;
    }

    function setVault(address vault_) external {
        vault = vault_;
    }

    function setHaircut(uint256 bps) external {
        haircutBps = bps;
    }

    function setLie(bool lie_) external {
        lie = lie_;
    }

    function totalAssets() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function withdraw(uint256 amount) external returns (uint256 sent) {
        require(msg.sender == vault, "only vault");
        uint256 lost = (amount * haircutBps) / 10_000;
        if (lost != 0) token.burn(address(this), lost);
        sent = amount - lost;
        token.transfer(vault, sent);
        if (lie) sent = amount;
    }
}

abstract contract VaultFixture is Test {
    StrategyVault public vault;
    MockStrategy public strat;
    MockERC20 public token;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public treasury = address(0xFEE);

    function setUp() public {
        token = new MockERC20("ASSET");
        strat = new MockStrategy(token);
        vault = new StrategyVault(IAsset(address(token)), IStrategy(address(strat)), treasury, 2000);
        strat.setVault(address(vault));
        token.mint(alice, 10_000 ether);
        token.mint(bob, 10_000 ether);
        vm.prank(alice);
        token.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        token.approve(address(vault), type(uint256).max);
    }

    function _deposit(address who, uint256 assets) internal returns (uint256 shares) {
        vm.prank(who);
        shares = vault.deposit(assets, who);
    }

    /// alice deposits 1000, 800 are invested
    function _seed() internal {
        _deposit(alice, 1000 ether);
        vault.invest(800 ether);
    }

    function _assertSolvent() internal view {
        assertGe(token.balanceOf(address(vault)), vault.idleAssets());
    }
}

contract StrategyVaultTest is VaultFixture {
    function testDepositMintsSharesOneToOne() public {
        assertEq(_deposit(alice, 1000 ether), 1000 ether);
        assertEq(vault.balanceOf(alice), 1000 ether);
        assertEq(vault.totalSupply(), 1000 ether);
        assertEq(vault.idleAssets(), 1000 ether);
        assertEq(vault.totalAssets(), 1000 ether);
    }

    function testInvestMovesIdleToStrategy() public {
        _seed();
        assertEq(vault.idleAssets(), 200 ether);
        assertEq(vault.strategyDebt(), 800 ether);
        assertEq(vault.totalAssets(), 1000 ether);
        assertEq(token.balanceOf(address(strat)), 800 ether);
    }

    function testProfitCountsOnlyAfterHarvest() public {
        _seed();
        token.mint(address(strat), 250 ether);
        assertEq(vault.totalAssets(), 1000 ether);
        assertEq(vault.convertToAssets(1000 ether), 1000 ether);
        (uint256 profit, uint256 loss, uint256 feeShares) = vault.harvest();
        assertEq(profit, 250 ether);
        assertEq(loss, 0);
        // fee = 20% of 250 = 50 assets, paid as 50 * 1000 / (1250 - 50) shares
        assertEq(feeShares, 41666666666666666666);
        assertEq(vault.balanceOf(treasury), 41666666666666666666);
        assertEq(vault.totalSupply(), 1000 ether + 41666666666666666666);
        assertEq(vault.totalAssets(), 1250 ether);
        assertEq(vault.strategyDebt(), 1050 ether);
        // alice keeps exactly the profit net of the fee
        assertEq(vault.convertToAssets(1000 ether), 1200 ether);
        assertEq(vault.convertToAssets(41666666666666666666), 50 ether - 1);
    }

    function testDepositAfterProfitUsesNewPrice() public {
        _seed();
        token.mint(address(strat), 250 ether);
        vault.harvest();
        assertEq(_deposit(bob, 625 ether), 520833333333333333333);
        assertEq(vault.totalAssets(), 1875 ether);
    }

    function testWithdrawFromIdle() public {
        _seed();
        vm.prank(alice);
        uint256 assets = vault.withdraw(100 ether, alice, 0);
        assertEq(assets, 100 ether);
        assertEq(token.balanceOf(alice), 9100 ether);
        assertEq(vault.idleAssets(), 100 ether);
        assertEq(vault.totalSupply(), 900 ether);
    }

    function testWithdrawPullsFromStrategy() public {
        _seed();
        vm.prank(alice);
        uint256 assets = vault.withdraw(500 ether, bob, 0);
        assertEq(assets, 500 ether);
        assertEq(token.balanceOf(bob), 10_500 ether);
        assertEq(vault.idleAssets(), 0);
        assertEq(vault.strategyDebt(), 500 ether);
        assertEq(token.balanceOf(address(strat)), 500 ether);
        assertEq(vault.convertToAssets(500 ether), 500 ether);
    }

    function testHarvestLossLowersPrice() public {
        _seed();
        token.burn(address(strat), 200 ether);
        (uint256 profit, uint256 loss, uint256 feeShares) = vault.harvest();
        assertEq(profit, 0);
        assertEq(loss, 200 ether);
        assertEq(feeShares, 0);
        assertEq(vault.unrecoveredLoss(), 200 ether);
        assertEq(vault.totalAssets(), 800 ether);
        assertEq(vault.convertToAssets(1000 ether), 800 ether);
    }

    function testOnlyOwnerOperates() public {
        _seed();
        vm.startPrank(alice);
        vm.expectRevert(StrategyVault.NotOwner.selector);
        vault.invest(1);
        vm.expectRevert(StrategyVault.NotOwner.selector);
        vault.divest(1);
        vm.expectRevert(StrategyVault.NotOwner.selector);
        vault.harvest();
        vm.stopPrank();
    }
}
