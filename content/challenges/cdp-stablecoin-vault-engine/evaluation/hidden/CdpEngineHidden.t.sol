// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CdpEngine.sol";

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

contract CdpEngineHiddenTest is Test {
    CdpEngine public engine;
    MockERC20 public coll;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    uint256 internal constant T0 = 1_700_000_000;
    uint256 internal constant RAY = 1e27;
    // 0.01% per second: 10% per 1000 seconds
    uint256 internal constant RPS = 1e23;

    function _deploy(uint256 ceiling) internal {
        coll = new MockERC20("COLL");
        engine = new CdpEngine(ICollateral(address(coll)), 2000 ether, 1.5 ether, 1.1 ether, RPS, ceiling);
        coll.mint(alice, 100 ether);
        coll.mint(bob, 100 ether);
        vm.prank(alice);
        coll.approve(address(engine), type(uint256).max);
        vm.prank(bob);
        coll.approve(address(engine), type(uint256).max);
    }

    function _open(address who, uint256 collateral, uint256 debt) internal {
        vm.prank(who);
        engine.deposit(collateral);
        vm.prank(who);
        engine.mint(debt);
    }

    function _art(address who) internal view returns (uint256 art) {
        (, art) = engine.vaults(who);
    }

    function _coll(address who) internal view returns (uint256 c) {
        (c, ) = engine.vaults(who);
    }

    function testHiddenRateCompoundsPerDrip() public {
        _deploy(1_000_000 ether);
        _open(alice, 10 ether, 1000 ether);
        vm.warp(T0 + 1000);
        engine.drip();
        vm.warp(T0 + 2000);
        // second interval applies 10% to 1.1
        assertEq(engine.currentRate(), 121 * RAY / 100);
        assertEq(engine.debtOf(alice), 1210 ether);
        engine.drip();
        assertEq(engine.surplus(), 210 ether);
        assertEq(engine.totalSupply(), 1210 ether);
        // dripping twice in one block changes nothing
        engine.drip();
        assertEq(engine.surplus(), 210 ether);
        assertEq(engine.rate(), 121 * RAY / 100);
    }

    function testHiddenSingleDripIsLinear() public {
        _deploy(1_000_000 ether);
        _open(alice, 10 ether, 1000 ether);
        vm.warp(T0 + 2000);
        assertEq(engine.drip(), 12 * RAY / 10);
        assertEq(engine.surplus(), 200 ether);
    }

    function testHiddenMintAfterAccrualRoundsDebtUp() public {
        _deploy(1_000_000 ether);
        _open(alice, 10 ether, 1000 ether);
        vm.warp(T0 + 1000);
        vm.prank(alice);
        engine.mint(110 ether);
        assertEq(_art(alice), 1100 ether);
        assertEq(engine.debtOf(alice), 1210 ether);
        vm.prank(alice);
        engine.mint(1); // ceil(1 / 1.1) = 1 unit of normalized debt
        assertEq(_art(alice), 1100 ether + 1);
        assertEq(engine.debtOf(alice), 1210 ether + 2); // ceil(1.1) = 2
        assertEq(engine.totalNormalizedDebt(), 1100 ether + 1);
        assertEq(engine.balanceOf(alice), 1110 ether + 1);
    }

    function testHiddenRepayRoundsNormalizedDebtDown() public {
        _deploy(1_000_000 ether);
        _open(alice, 10 ether, 1000 ether);
        vm.warp(T0 + 1000);
        vm.prank(alice);
        assertEq(engine.repay(1), 1); // floor(1 / 1.1) = 0: the payment is burned, debt unchanged
        assertEq(_art(alice), 1000 ether);
        assertEq(engine.balanceOf(alice), 1000 ether - 1);
        vm.prank(alice);
        engine.repay(11);
        assertEq(_art(alice), 1000 ether - 10);
    }

    function testHiddenBadDebtAndHeal() public {
        _deploy(1_000_000 ether);
        _open(alice, 1 ether, 1000 ether);
        _open(bob, 20 ether, 5000 ether);
        engine.setPrice(550 ether);
        vm.prank(bob);
        (uint256 repaid, uint256 seized) = engine.liquidate(alice, 1000 ether);
        // 1000 * 1.1 / 550 = 2 collateral wanted, only 1 exists: pay 1 * 550 / 1.1 = 500
        assertEq(seized, 1 ether);
        assertEq(repaid, 500 ether);
        assertEq(engine.badDebt(), 500 ether);
        assertEq(_art(alice), 0);
        assertEq(_coll(alice), 0);
        assertEq(engine.totalNormalizedDebt(), 5000 ether);
        assertEq(engine.totalSupply(), 5500 ether);
        assertEq(engine.heal(), 0);

        vm.warp(T0 + 1000);
        engine.drip();
        assertEq(engine.surplus(), 500 ether);
        vm.expectRevert(CdpEngine.BadDebtOutstanding.selector);
        engine.withdrawSurplus(address(this), 1);
        vm.prank(alice); // anyone may heal
        assertEq(engine.heal(), 500 ether);
        assertEq(engine.badDebt(), 0);
        assertEq(engine.surplus(), 0);
        // supply is again fully backed by bob's debt
        assertEq(engine.totalSupply(), 5500 ether);
        assertEq(engine.totalDebt(), 5500 ether);
    }

    function testHiddenHealIsCappedBySurplus() public {
        _deploy(1_000_000 ether);
        _open(alice, 1 ether, 1000 ether);
        _open(bob, 20 ether, 1000 ether);
        engine.setPrice(550 ether);
        vm.prank(bob);
        engine.liquidate(alice, 1000 ether);
        vm.warp(T0 + 1000);
        engine.drip(); // fee on bob's 1000 = 100
        assertEq(engine.heal(), 100 ether);
        assertEq(engine.badDebt(), 400 ether);
        assertEq(engine.surplus(), 0);
    }

    function testHiddenFullLiquidationLeavesExcessCollateral() public {
        _deploy(1_000_000 ether);
        _open(alice, 1 ether, 1000 ether);
        _open(bob, 20 ether, 5000 ether);
        engine.setPrice(1400 ether);
        vm.prank(bob);
        (uint256 repaid, uint256 seized) = engine.liquidate(alice, 9999 ether);
        assertEq(repaid, 1000 ether);
        assertEq(seized, 785714285714285714); // floor(1100 / 1400)
        assertEq(_art(alice), 0);
        assertEq(engine.badDebt(), 0);
        assertEq(_coll(alice), 214285714285714286);
        vm.prank(alice);
        engine.withdraw(214285714285714286);
        assertEq(coll.balanceOf(address(engine)), 20 ether);
    }

    function testHiddenLiquidationAfterAccrual() public {
        _deploy(1_000_000 ether);
        _open(alice, 1 ether, 1200 ether);
        _open(bob, 20 ether, 5000 ether);
        // safe at first: 2000 >= 1800. After 20% accrual the debt is 1440 and needs 2160.
        vm.prank(bob);
        vm.expectRevert(CdpEngine.VaultIsSafe.selector);
        engine.liquidate(alice, 100 ether);
        vm.warp(T0 + 2000);
        assertFalse(engine.isSafe(alice));
        vm.prank(bob);
        (uint256 repaid, uint256 seized) = engine.liquidate(alice, 720 ether);
        assertEq(repaid, 720 ether);
        assertEq(seized, 0.396 ether); // 720 * 1.1 / 2000
        assertEq(_art(alice), 600 ether);
        assertEq(engine.debtOf(alice), 720 ether);
        assertEq(engine.surplus(), 1240 ether); // 20% of 6200
    }

    function testHiddenDebtCeilingCountsAccruedFees() public {
        _deploy(1050 ether);
        _open(alice, 10 ether, 1000 ether);
        vm.prank(alice);
        vm.expectRevert(CdpEngine.DebtCeilingExceeded.selector);
        engine.mint(51 ether);
        vm.prank(alice);
        engine.mint(50 ether);
        vm.warp(T0 + 1000);
        vm.prank(alice);
        vm.expectRevert(CdpEngine.DebtCeilingExceeded.selector);
        engine.mint(1);
    }

    function testHiddenAdminControls() public {
        _deploy(1_000_000 ether);
        vm.prank(alice);
        vm.expectRevert(CdpEngine.NotOwner.selector);
        engine.setPrice(1);
        vm.prank(alice);
        vm.expectRevert(CdpEngine.NotOwner.selector);
        engine.setRatePerSecond(0);
        vm.prank(alice);
        vm.expectRevert(CdpEngine.NotOwner.selector);
        engine.withdrawSurplus(alice, 0);

        _open(alice, 10 ether, 1000 ether);
        vm.warp(T0 + 1000);
        engine.setRatePerSecond(0); // must apply the old rate up to now first
        assertEq(engine.rate(), 11 * RAY / 10);
        vm.warp(T0 + 5000);
        assertEq(engine.currentRate(), 11 * RAY / 10);
        assertEq(engine.debtOf(alice), 1100 ether);

        vm.expectRevert(CdpEngine.InsufficientBalance.selector);
        engine.withdrawSurplus(bob, 100 ether + 1);
        engine.withdrawSurplus(bob, 100 ether);
        assertEq(engine.balanceOf(bob), 100 ether);
        assertEq(engine.surplus(), 0);
    }

    function testHiddenInputValidation() public {
        _deploy(1_000_000 ether);
        vm.startPrank(alice);
        vm.expectRevert(CdpEngine.ZeroAmount.selector);
        engine.deposit(0);
        engine.deposit(1 ether);
        vm.expectRevert(CdpEngine.ZeroAmount.selector);
        engine.mint(0);
        vm.expectRevert(CdpEngine.ZeroAmount.selector);
        engine.withdraw(0);
        vm.expectRevert(CdpEngine.InsufficientCollateral.selector);
        engine.withdraw(1 ether + 1);
        engine.mint(100 ether);
        vm.expectRevert(CdpEngine.ZeroAmount.selector);
        engine.repay(0);
        engine.transfer(bob, 60 ether);
        vm.expectRevert(CdpEngine.InsufficientBalance.selector);
        engine.repay(50 ether);
        vm.expectRevert(CdpEngine.InsufficientBalance.selector);
        engine.transfer(bob, 41 ether);
        vm.stopPrank();
        assertEq(engine.balanceOf(bob), 60 ether);
        assertEq(engine.totalSupply(), 100 ether);
    }

    function testHiddenLiquidatorNeedsStablecoin() public {
        _deploy(1_000_000 ether);
        _open(alice, 1 ether, 1000 ether);
        engine.setPrice(1100 ether);
        vm.prank(bob); // bob holds no stablecoin
        vm.expectRevert(CdpEngine.InsufficientBalance.selector);
        engine.liquidate(alice, 500 ether);
        assertEq(_coll(alice), 1 ether);
    }
}
