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

contract StrategyVaultHiddenTest is VaultFixture {
    function testHiddenNoFeeUntilLossIsRecovered() public {
        _seed();
        token.mint(address(strat), 250 ether);
        vault.harvest(); // supply 1041.66.., debt 1050
        uint256 supply = vault.totalSupply();

        token.burn(address(strat), 300 ether);
        (, uint256 loss, uint256 feeShares) = vault.harvest();
        assertEq(loss, 300 ether);
        assertEq(feeShares, 0);
        assertEq(vault.unrecoveredLoss(), 300 ether);
        assertEq(vault.totalAssets(), 950 ether);

        // 200 of profit only recovers part of the loss: no fee
        token.mint(address(strat), 200 ether);
        (uint256 profit, , uint256 fs) = vault.harvest();
        assertEq(profit, 200 ether);
        assertEq(fs, 0);
        assertEq(vault.unrecoveredLoss(), 100 ether);
        assertEq(vault.totalSupply(), supply);

        // 300 more: 100 recover, 200 are feeable -> fee 40 on total assets 1450
        token.mint(address(strat), 300 ether);
        (profit, , fs) = vault.harvest();
        assertEq(profit, 300 ether);
        assertEq(fs, 29550827423167848699);
        assertEq(vault.unrecoveredLoss(), 0);
        assertEq(vault.totalAssets(), 1450 ether);
        assertEq(vault.totalSupply(), supply + 29550827423167848699);
    }

    function testHiddenHarvestWithoutChangeIsNoop() public {
        _seed();
        (uint256 profit, uint256 loss, uint256 feeShares) = vault.harvest();
        assertEq(profit + loss + feeShares, 0);
        assertEq(vault.totalSupply(), 1000 ether);
        assertEq(vault.strategyDebt(), 800 ether);
        // harvesting twice does not charge the same profit twice
        token.mint(address(strat), 250 ether);
        vault.harvest();
        (profit, , feeShares) = vault.harvest();
        assertEq(profit, 0);
        assertEq(feeShares, 0);
    }

    function testHiddenDonationsDoNotMoveThePrice() public {
        _deposit(alice, 1 ether);
        token.mint(address(vault), 1000 ether); // direct transfer, not a deposit
        assertEq(vault.totalAssets(), 1 ether);
        assertEq(_deposit(bob, 1 ether), 1 ether);
        vm.prank(alice);
        assertEq(vault.withdraw(1 ether, alice, 0), 1 ether);
        // a donation to the strategy is profit at the next harvest, with the fee applied
        vault.invest(1 ether);
        token.mint(address(strat), 1 ether);
        (uint256 profit, , uint256 feeShares) = vault.harvest();
        assertEq(profit, 1 ether);
        assertEq(feeShares, uint256(0.2 ether) * 1 ether / 1.8 ether);
    }

    function testHiddenWithdrawShortfallIsBorneByWithdrawer() public {
        _deposit(alice, 500 ether);
        _deposit(bob, 500 ether);
        vault.invest(800 ether);
        strat.setHaircut(1000); // strategy loses 10% of what is pulled

        // 500 owed: 200 idle + 300 requested, 270 arrive -> loss 30 (6% of 500)
        vm.prank(alice);
        vm.expectRevert(StrategyVault.LossTooHigh.selector);
        vault.withdraw(500 ether, alice, 599);
        vm.prank(alice);
        uint256 assets = vault.withdraw(500 ether, alice, 600);
        assertEq(assets, 470 ether);
        assertEq(token.balanceOf(alice), 10_000 ether - 30 ether);
        assertEq(vault.idleAssets(), 0);
        assertEq(vault.strategyDebt(), 500 ether);
        assertEq(vault.totalSupply(), 500 ether);
        assertEq(vault.unrecoveredLoss(), 0);
        // bob's claim is untouched by alice's exit
        assertEq(vault.convertToAssets(500 ether), 500 ether);
        assertEq(token.balanceOf(address(strat)), 500 ether);
        _assertSolvent();
    }

    function testHiddenLyingStrategyIsMeasuredNotTrusted() public {
        _seed();
        strat.setHaircut(5000);
        strat.setLie(true); // claims to have returned everything
        uint256 received = vault.divest(400 ether);
        assertEq(received, 200 ether);
        assertEq(vault.idleAssets(), 400 ether);
        assertEq(vault.strategyDebt(), 400 ether);
        assertEq(vault.unrecoveredLoss(), 200 ether);
        assertEq(vault.totalAssets(), 800 ether);
        assertEq(token.balanceOf(address(vault)), 400 ether);

        vm.prank(alice);
        vm.expectRevert(StrategyVault.LossTooHigh.selector);
        vault.withdraw(1000 ether, alice, 0);
        // 800 owed: 400 idle + 400 requested, 200 arrive
        vm.prank(alice);
        assertEq(vault.withdraw(1000 ether, alice, 2500), 600 ether);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);
        assertEq(token.balanceOf(address(vault)), 0);
    }

    function testHiddenDivestWithoutLoss() public {
        _seed();
        vm.expectRevert(StrategyVault.InsufficientDebt.selector);
        vault.divest(800 ether + 1);
        assertEq(vault.divest(300 ether), 300 ether);
        assertEq(vault.idleAssets(), 500 ether);
        assertEq(vault.strategyDebt(), 500 ether);
        assertEq(vault.unrecoveredLoss(), 0);
        vm.expectRevert(StrategyVault.InsufficientIdle.selector);
        vault.invest(500 ether + 1);
    }

    function testHiddenRoundingAndZeroShares() public {
        _seed();
        token.mint(address(strat), 250 ether);
        vault.harvest(); // price is now 1.2
        vm.prank(bob);
        vm.expectRevert(StrategyVault.ZeroShares.selector);
        vault.deposit(1, bob);
        // 7 wei of assets buy floor(7 / 1.2) = 5 shares, which are worth floor(5 * 1.2) = 6
        assertEq(_deposit(bob, 7), 5);
        assertEq(vault.convertToAssets(5), 6);
        vm.prank(bob);
        assertEq(vault.withdraw(5, bob, 0), 6);
        assertEq(token.balanceOf(bob), 10_000 ether - 1);
        _assertSolvent();
    }

    function testHiddenInputValidation() public {
        vm.expectRevert(StrategyVault.FeeTooHigh.selector);
        new StrategyVault(IAsset(address(token)), IStrategy(address(strat)), treasury, 5001);
        new StrategyVault(IAsset(address(token)), IStrategy(address(strat)), treasury, 5000);

        vm.startPrank(alice);
        vm.expectRevert(StrategyVault.ZeroAmount.selector);
        vault.deposit(0, alice);
        vault.deposit(10 ether, bob); // shares go to the receiver
        vm.expectRevert(StrategyVault.InsufficientShares.selector);
        vault.withdraw(1, alice, 10_000);
        vm.stopPrank();
        assertEq(vault.balanceOf(bob), 10 ether);
        vm.startPrank(bob);
        vm.expectRevert(StrategyVault.ZeroAmount.selector);
        vault.withdraw(0, bob, 0);
        vm.expectRevert(StrategyVault.InsufficientShares.selector);
        vault.withdraw(10 ether + 1, bob, 0);
        vm.stopPrank();
    }

    function testHiddenFeeRecipientCanRedeemFeeShares() public {
        _seed();
        token.mint(address(strat), 250 ether);
        vault.harvest();
        vm.prank(treasury);
        uint256 assets = vault.withdraw(41666666666666666666, treasury, 0);
        assertEq(assets, 50 ether - 1);
        assertEq(token.balanceOf(treasury), 50 ether - 1);
        // alice then exits with everything that is left, pulling the rest from the strategy
        vm.prank(alice);
        assertEq(vault.withdraw(1000 ether, alice, 0), 1200 ether + 1);
        assertEq(vault.totalSupply(), 0);
        assertEq(token.balanceOf(address(strat)), 0);
        assertEq(token.balanceOf(address(vault)), 0);
    }

    function testHiddenProfitWithNoSharesMintsNoFee() public {
        _seed();
        vm.prank(alice);
        vault.withdraw(1000 ether, alice, 0);
        assertEq(vault.totalSupply(), 0);
        token.mint(address(strat), 10 ether);
        (uint256 profit, , uint256 feeShares) = vault.harvest();
        assertEq(profit, 10 ether);
        assertEq(feeShares, 0);
        assertEq(vault.totalSupply(), 0);
    }
}
