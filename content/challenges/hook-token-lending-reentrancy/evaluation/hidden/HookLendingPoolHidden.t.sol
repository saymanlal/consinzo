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

/// Borrows from inside the hook, while the withdrawn collateral is still on the books.
contract BorrowInHook is ITokenHook {
    HookLendingPool public immutable pool;
    HookToken public immutable token;
    uint256 internal borrowAmount;

    constructor(HookLendingPool _pool, HookToken _token) {
        pool = _pool;
        token = _token;
        token.registerHook();
        token.approve(address(_pool), type(uint256).max);
    }

    function attack(uint256 amount) external {
        pool.depositCollateral(amount);
        borrowAmount = amount / 2;
        pool.withdrawCollateral(amount);
    }

    function onTokenReceived(address from, uint256) external {
        if (from == address(pool) && borrowAmount != 0) {
            uint256 b = borrowAmount;
            borrowAmount = 0;
            try pool.borrow(b) {} catch {}
        }
    }
}

/// Withdraws in slices and re-enters several levels deep.
contract SliceWithdrawer is ITokenHook {
    HookLendingPool public immutable pool;
    HookToken public immutable token;
    uint256 internal depth;

    constructor(HookLendingPool _pool, HookToken _token) {
        pool = _pool;
        token = _token;
        token.registerHook();
        token.approve(address(_pool), type(uint256).max);
    }

    function attack(uint256 deposit, uint256 slice) external {
        pool.depositCollateral(deposit);
        pool.withdrawCollateral(slice);
    }

    function onTokenReceived(address from, uint256 amount) external {
        if (from == address(pool) && depth < 3) {
            depth++;
            try pool.withdrawCollateral(amount) {} catch {}
        }
    }
}

/// Honest contract wallet with a hook that does nothing harmful.
contract QuietWallet is ITokenHook {
    uint256 public notifications;

    function setup(HookLendingPool pool, HookToken token) external {
        token.registerHook();
        token.approve(address(pool), type(uint256).max);
    }

    function deposit(HookLendingPool pool, uint256 amount) external {
        pool.depositCollateral(amount);
    }

    function withdraw(HookLendingPool pool, uint256 amount) external {
        pool.withdrawCollateral(amount);
    }

    function onTokenReceived(address, uint256) external {
        notifications++;
    }
}

contract HookLendingPoolHiddenTest is Test {
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

    function testHiddenCannotBorrowAgainstCollateralBeingWithdrawn() public {
        BorrowInHook attacker = new BorrowInHook(pool, collateral);
        collateral.mint(address(attacker), 100e18);
        attacker.attack(100e18);

        uint256 debt = pool.debtOf(address(attacker));
        uint256 backing = pool.collateralOf(address(attacker));
        assertLe(debt, pool.maxDebtFor(backing));
        assertEq(stable.balanceOf(address(attacker)), debt);
        // Collateral in the pool always covers what the books say.
        assertEq(collateral.balanceOf(address(pool)), pool.totalCollateral());
    }

    function testHiddenNestedSliceWithdrawalsStayConsistent() public {
        SliceWithdrawer attacker = new SliceWithdrawer(pool, collateral);
        collateral.mint(address(attacker), 100e18);
        attacker.attack(100e18, 30e18);

        uint256 held = collateral.balanceOf(address(attacker));
        uint256 booked = pool.collateralOf(address(attacker));
        // Tokens in hand plus tokens still booked equal the original 100.
        assertEq(held + booked, 100e18);
        assertEq(pool.totalCollateral(), 500e18 + booked);
        assertEq(collateral.balanceOf(address(pool)), pool.totalCollateral());
    }

    function testHiddenHonestHookedWalletWorks() public {
        QuietWallet wallet = new QuietWallet();
        wallet.setup(pool, collateral);
        collateral.mint(address(wallet), 80e18);
        wallet.deposit(pool, 80e18);
        assertEq(pool.collateralOf(address(wallet)), 80e18);
        wallet.withdraw(pool, 30e18);
        wallet.withdraw(pool, 50e18);
        assertEq(collateral.balanceOf(address(wallet)), 80e18);
        assertEq(pool.collateralOf(address(wallet)), 0);
        assertEq(wallet.notifications(), 2); // one per withdrawal
        assertEq(pool.totalCollateral(), 500e18);
    }

    function testHiddenLtvBoundaries() public {
        vm.startPrank(alice);
        pool.borrow(250e18); // exactly 50%
        vm.stopPrank();
        assertEq(pool.debtOf(alice), 250e18);

        vm.expectRevert(HookLendingPool.Unhealthy.selector);
        vm.prank(alice);
        pool.borrow(1);

        vm.expectRevert(HookLendingPool.Unhealthy.selector);
        vm.prank(alice);
        pool.withdrawCollateral(1);

        vm.prank(alice);
        pool.repay(50e18);
        vm.prank(alice);
        pool.withdrawCollateral(100e18); // 400 collateral backs 200 debt exactly
        assertEq(pool.collateralOf(alice), 400e18);
        assertEq(pool.totalCollateral(), 400e18);
    }

    function testHiddenInputValidation() public {
        vm.expectRevert(HookLendingPool.InsufficientCollateral.selector);
        vm.prank(alice);
        pool.withdrawCollateral(500e18 + 1);

        vm.expectRevert(HookLendingPool.ZeroAmount.selector);
        vm.prank(alice);
        pool.withdrawCollateral(0);

        vm.expectRevert(HookLendingPool.RepayExceedsDebt.selector);
        vm.prank(alice);
        pool.repay(1);
        assertEq(pool.collateralOf(alice), 500e18);
    }
}
