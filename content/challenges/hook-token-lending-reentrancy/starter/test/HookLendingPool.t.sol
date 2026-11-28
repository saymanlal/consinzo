// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/HookLendingPool.sol";

contract PlainToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _move(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        _move(from, to, amount);
        return true;
    }

    function _move(address from, address to, uint256 amount) internal virtual {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
    }
}

interface ITokenHook {
    function onTokenReceived(address from, uint256 amount) external;
}

/// ERC-777 style token: recipients that registered a hook are called after each transfer.
contract HookToken is PlainToken {
    mapping(address => bool) public hasHook;

    function registerHook() external {
        hasHook[msg.sender] = true;
    }

    function _move(address from, address to, uint256 amount) internal override {
        super._move(from, to, amount);
        if (hasHook[to]) ITokenHook(to).onTokenReceived(from, amount);
    }
}

/// Re-enters withdrawCollateral from the token hook to be paid twice.
contract DoubleWithdrawer is ITokenHook {
    HookLendingPool public immutable pool;
    HookToken public immutable token;
    bool internal reentered;

    constructor(HookLendingPool _pool, HookToken _token) {
        pool = _pool;
        token = _token;
        token.registerHook();
        token.approve(address(_pool), type(uint256).max);
    }

    function attack(uint256 amount) external {
        pool.depositCollateral(amount);
        pool.withdrawCollateral(amount);
    }

    function onTokenReceived(address from, uint256 amount) external {
        if (from == address(pool) && !reentered) {
            reentered = true;
            try pool.withdrawCollateral(amount) {} catch {}
        }
    }
}

contract HookLendingPoolTest is Test {
    HookLendingPool public pool;
    HookToken public collateral;
    PlainToken public stable;
    address public alice = address(0xA11CE);

    function setUp() public {
        collateral = new HookToken();
        stable = new PlainToken();
        pool = new HookLendingPool(IERC20Like(address(collateral)), IERC20Like(address(stable)));
        stable.mint(address(pool), 10_000e18);

        collateral.mint(alice, 500e18);
        vm.startPrank(alice);
        collateral.approve(address(pool), type(uint256).max);
        stable.approve(address(pool), type(uint256).max);
        pool.depositCollateral(500e18);
        vm.stopPrank();
    }

    function testBorrowRepayWithdrawLifecycle() public {
        vm.startPrank(alice);
        pool.borrow(250e18);
        assertEq(stable.balanceOf(alice), 250e18);
        pool.repay(250e18);
        pool.withdrawCollateral(500e18);
        vm.stopPrank();
        assertEq(collateral.balanceOf(alice), 500e18);
        assertEq(pool.collateralOf(alice), 0);
        assertEq(pool.totalCollateral(), 0);
    }

    function testCannotBorrowAboveLtv() public {
        vm.expectRevert(HookLendingPool.Unhealthy.selector);
        vm.prank(alice);
        pool.borrow(250e18 + 1);
        assertEq(pool.debtOf(alice), 0);
    }

    function testCannotWithdrawCollateralBackingDebt() public {
        vm.prank(alice);
        pool.borrow(200e18);
        vm.expectRevert(HookLendingPool.Unhealthy.selector);
        vm.prank(alice);
        pool.withdrawCollateral(100e18 + 1);
        assertEq(pool.collateralOf(alice), 500e18);
    }

    function testHookCannotWithdrawCollateralTwice() public {
        DoubleWithdrawer attacker = new DoubleWithdrawer(pool, collateral);
        collateral.mint(address(attacker), 100e18);
        attacker.attack(100e18);

        // The attacker gets back at most what it put in; alice's collateral is untouched.
        assertLe(collateral.balanceOf(address(attacker)), 100e18);
        assertEq(collateral.balanceOf(address(pool)), 500e18);
        assertEq(pool.totalCollateral(), 500e18);
        assertEq(pool.collateralOf(alice), 500e18);
    }
}
