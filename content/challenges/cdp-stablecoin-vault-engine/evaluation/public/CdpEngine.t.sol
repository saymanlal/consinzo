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

contract CdpEngineTest is Test {
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

    function setUp() public {
        _deploy(1_000_000 ether);
    }

    function testDepositAndMint() public {
        _open(alice, 1 ether, 1000 ether);
        assertEq(engine.balanceOf(alice), 1000 ether);
        assertEq(engine.totalSupply(), 1000 ether);
        assertEq(_coll(alice), 1 ether);
        assertEq(_art(alice), 1000 ether);
        assertEq(engine.debtOf(alice), 1000 ether);
        assertEq(coll.balanceOf(address(engine)), 1 ether);
        assertTrue(engine.isSafe(alice));
    }

    function testMintLimitedByLiquidationRatio() public {
        _open(alice, 1 ether, 1000 ether);
        // 2000 of collateral value supports at most 1333.33 of debt at 150%
        vm.prank(alice);
        vm.expectRevert(CdpEngine.UnsafeVault.selector);
        engine.mint(334 ether);
        vm.prank(alice);
        engine.mint(333 ether);
        assertEq(engine.debtOf(alice), 1333 ether);
    }

    function testStabilityFeeAccrues() public {
        _open(alice, 1 ether, 1000 ether);
        vm.warp(T0 + 1000);
        assertEq(engine.currentRate(), 11 * RAY / 10);
        assertEq(engine.debtOf(alice), 1100 ether);
        assertEq(engine.surplus(), 0); // nothing minted until drip
        assertEq(engine.drip(), 11 * RAY / 10);
        assertEq(engine.surplus(), 100 ether);
        assertEq(engine.totalSupply(), 1100 ether);
        assertEq(engine.lastDrip(), T0 + 1000);
    }

    function testRepayPartialThenFull() public {
        _open(alice, 1 ether, 1000 ether);
        _open(bob, 10 ether, 1000 ether);
        vm.warp(T0 + 1000);
        vm.prank(alice);
        assertEq(engine.repay(550 ether), 550 ether);
        assertEq(_art(alice), 500 ether);
        assertEq(engine.debtOf(alice), 550 ether);
        assertEq(engine.balanceOf(alice), 450 ether);

        vm.prank(bob);
        engine.transfer(alice, 100 ether);
        vm.prank(alice);
        assertEq(engine.repay(type(uint256).max), 550 ether);
        assertEq(_art(alice), 0);
        assertEq(engine.balanceOf(alice), 0);
        vm.prank(alice);
        engine.withdraw(1 ether);
        assertEq(coll.balanceOf(alice), 100 ether);
    }

    function testWithdrawMustKeepVaultSafe() public {
        _open(alice, 1 ether, 1000 ether);
        vm.prank(alice);
        engine.withdraw(0.25 ether); // 0.75 * 2000 = 1500 = 1000 * 1.5
        vm.prank(alice);
        vm.expectRevert(CdpEngine.UnsafeVault.selector);
        engine.withdraw(1);
    }

    function testPartialLiquidation() public {
        _open(alice, 1 ether, 1000 ether);
        _open(bob, 10 ether, 5000 ether);
        engine.setPrice(1100 ether);
        assertFalse(engine.isSafe(alice));
        vm.prank(bob);
        (uint256 repaid, uint256 seized) = engine.liquidate(alice, 500 ether);
        assertEq(repaid, 500 ether);
        assertEq(seized, 0.5 ether); // 500 * 1.1 / 1100
        assertEq(engine.debtOf(alice), 500 ether);
        assertEq(_coll(alice), 0.5 ether);
        assertEq(engine.balanceOf(bob), 4500 ether);
        assertEq(coll.balanceOf(bob), 90.5 ether);
        assertEq(engine.totalSupply(), 5500 ether);
        assertEq(engine.badDebt(), 0);
    }

    function testCannotLiquidateSafeVault() public {
        _open(alice, 1 ether, 1000 ether);
        _open(bob, 10 ether, 5000 ether);
        vm.prank(bob);
        vm.expectRevert(CdpEngine.VaultIsSafe.selector);
        engine.liquidate(alice, 100 ether);
    }
}
