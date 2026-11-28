// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FastBridgePool.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

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

contract FastBridgePoolHiddenTest is Test {
    FastBridgePool public pool;
    MockERC20 public usd;
    address public relayer = address(0x4E1A);
    address public settler = address(0x5E77);
    address public lp1 = address(0x1111);
    address public lp2 = address(0x2222);
    address public user = address(0xA11CE);
    address public mallory = address(0xBAD);

    function setUp() public {
        usd = new MockERC20();
        pool = new FastBridgePool(address(usd), relayer, settler, 10, 2_000);
        address[4] memory holders = [lp1, lp2, settler, mallory];
        for (uint256 i = 0; i < holders.length; i++) {
            usd.mint(holders[i], 1_000_000e18);
            vm.prank(holders[i]);
            usd.approve(address(pool), type(uint256).max);
        }
    }

    function _id(uint256 n) internal pure returns (bytes32) {
        return keccak256(abi.encode("transfer", n));
    }

    function _deposit(address lp, uint256 assets) internal returns (uint256 shares) {
        vm.prank(lp);
        shares = pool.deposit(assets);
    }

    function _fulfill(uint256 n, uint256 amount) internal returns (uint256 paid) {
        vm.prank(relayer);
        paid = pool.fulfill(_id(n), user, amount);
    }

    function _settle(uint256 n, uint256 amount) internal {
        vm.prank(settler);
        pool.settle(_id(n), user, amount);
    }

    function _assertBalanced() internal view {
        assertEq(usd.balanceOf(address(pool)), pool.idle() + pool.protocolFees());
    }

    function testHiddenConstructorValidation() public {
        vm.expectRevert(FastBridgePool.InvalidConfig.selector);
        new FastBridgePool(address(0), relayer, settler, 10, 2_000);
        vm.expectRevert(FastBridgePool.InvalidConfig.selector);
        new FastBridgePool(address(usd), address(0), settler, 10, 2_000);
        vm.expectRevert(FastBridgePool.InvalidConfig.selector);
        new FastBridgePool(address(usd), relayer, address(0), 10, 2_000);
        vm.expectRevert(FastBridgePool.InvalidConfig.selector);
        new FastBridgePool(address(usd), relayer, settler, 1_001, 2_000);
        vm.expectRevert(FastBridgePool.InvalidConfig.selector);
        new FastBridgePool(address(usd), relayer, settler, 10, 10_001);
        FastBridgePool p = new FastBridgePool(address(usd), relayer, settler, 1_000, 10_000);
        assertEq(p.owner(), address(this));
        assertEq(p.feeBps(), 1_000);
        assertEq(p.protocolShareBps(), 10_000);
    }

    function testHiddenFulfillThenSlowSettleOrderings() public {
        _deposit(lp1, 100_000e18);

        // settle first (slow path), then a late fulfil for the same id must not pay again
        _settle(1, 5_000e18);
        assertEq(usd.balanceOf(user), 5_000e18);
        vm.prank(relayer);
        vm.expectRevert(FastBridgePool.AlreadyHandled.selector);
        pool.fulfill(_id(1), user, 5_000e18);
        assertEq(pool.outstanding(), 0);
        assertEq(pool.idle(), 100_000e18);

        // fulfil twice
        _fulfill(2, 5_000e18);
        vm.prank(relayer);
        vm.expectRevert(FastBridgePool.AlreadyHandled.selector);
        pool.fulfill(_id(2), user, 5_000e18);

        // settle twice, after either path
        _settle(2, 5_000e18);
        vm.startPrank(settler);
        vm.expectRevert(FastBridgePool.AlreadySettled.selector);
        pool.settle(_id(2), user, 5_000e18);
        vm.expectRevert(FastBridgePool.AlreadySettled.selector);
        pool.settle(_id(1), user, 5_000e18);
        vm.stopPrank();

        assertEq(usd.balanceOf(user), 5_000e18 + 4_995e18);
        _assertBalanced();
    }

    function testHiddenSettlementTermsMustMatch() public {
        _deposit(lp1, 100_000e18);
        _fulfill(1, 10_000e18);

        vm.startPrank(settler);
        vm.expectRevert(FastBridgePool.TermsMismatch.selector);
        pool.settle(_id(1), user, 9_990e18); // only what was fronted: LPs would earn nothing
        vm.expectRevert(FastBridgePool.TermsMismatch.selector);
        pool.settle(_id(1), mallory, 10_000e18);
        vm.stopPrank();

        // a failed settlement leaves the transfer open
        assertTrue(pool.transferState(_id(1)) == FastBridgePool.State.Fulfilled);
        assertEq(pool.outstanding(), 9_990e18);
        _settle(1, 10_000e18);
        assertEq(pool.outstanding(), 0);
        _assertBalanced();
    }

    function testHiddenFulfillValidationOrder() public {
        _deposit(lp1, 1_000e18);
        vm.prank(mallory);
        vm.expectRevert(FastBridgePool.NotRelayer.selector);
        pool.fulfill(_id(1), address(0), 0);
        vm.startPrank(relayer);
        vm.expectRevert(FastBridgePool.ZeroAddress.selector);
        pool.fulfill(_id(1), address(0), 0);
        vm.expectRevert(FastBridgePool.ZeroAmount.selector);
        pool.fulfill(_id(1), user, 0);
        vm.expectRevert(FastBridgePool.InsufficientIdleLiquidity.selector);
        pool.fulfill(_id(1), user, 1_002e18); // pays 1000.998 > 1000 idle
        pool.fulfill(_id(1), user, 1_001e18); // pays 999.999
        vm.expectRevert(FastBridgePool.AlreadyHandled.selector);
        pool.fulfill(_id(1), user, 1_000_000e18); // state is checked before liquidity
        vm.stopPrank();
        assertEq(pool.idle(), 1_000e18 - 999.999e18);
    }

    function testHiddenSettleValidationOrder() public {
        vm.prank(relayer);
        vm.expectRevert(FastBridgePool.NotSettler.selector);
        pool.settle(_id(1), address(0), 0);
        vm.startPrank(settler);
        vm.expectRevert(FastBridgePool.ZeroAddress.selector);
        pool.settle(_id(1), address(0), 0);
        vm.expectRevert(FastBridgePool.ZeroAmount.selector);
        pool.settle(_id(1), user, 0);
        vm.stopPrank();
        assertTrue(pool.transferState(_id(1)) == FastBridgePool.State.None);
    }

    function testHiddenOutstandingCapitalCannotBeWithdrawn() public {
        _deposit(lp1, 60_000e18);
        _deposit(lp2, 40_000e18);
        _fulfill(1, 80_000e18); // pays 79_920
        assertEq(pool.idle(), 20_080e18);

        vm.prank(lp1);
        vm.expectRevert(FastBridgePool.InsufficientIdleLiquidity.selector);
        pool.withdraw(60_000e18);

        // a partial exit within idle liquidity works and is priced at cost
        vm.prank(lp1);
        assertEq(pool.withdraw(20_080e18), 20_080e18);
        assertEq(pool.idle(), 0);
        assertEq(pool.totalAssets(), 79_920e18);

        _settle(1, 80_000e18);
        // remaining shares: lp1 39_920, lp2 40_000; LP fee share 64
        assertEq(pool.totalAssets(), 79_984e18);
        vm.prank(lp2);
        uint256 out2 = pool.withdraw(40_000e18);
        vm.prank(lp1);
        uint256 out1 = pool.withdraw(39_920e18);
        assertEq(out1 + out2, 79_984e18);
        assertGt(out2, 40_000e18);
        assertEq(pool.totalShares(), 0);
        assertEq(pool.idle(), 0);
        assertEq(usd.balanceOf(address(pool)), pool.protocolFees());
        assertEq(pool.protocolFees(), 16e18);
    }

    function testHiddenDepositWhileOutstandingUsesCostBasis() public {
        _deposit(lp1, 100_000e18);
        _fulfill(1, 50_000e18);
        // total assets are still 100_000, so a newcomer gets shares 1:1
        assertEq(_deposit(lp2, 25_000e18), 25_000e18);
        assertEq(pool.convertToAssets(25_000e18), 25_000e18);
        _settle(1, 50_000e18);
        // LP fee share 40 is spread over 125_000 shares
        assertEq(pool.totalAssets(), 125_040e18);
        assertEq(pool.convertToAssets(25_000e18), 25_008e18);
    }

    function testHiddenDonationDoesNotMoveSharePrice() public {
        _deposit(lp1, 1e18);
        vm.prank(mallory);
        usd.transfer(address(pool), 500_000e18);

        assertEq(pool.totalAssets(), 1e18);
        assertEq(pool.idle(), 1e18);
        assertEq(_deposit(lp2, 10e18), 10e18); // not rounded to zero by the donation
        vm.prank(lp1);
        assertEq(pool.withdraw(1e18), 1e18); // and the donor's tokens are not paid out
        // donated tokens cannot be used to front transfers either
        vm.prank(relayer);
        vm.expectRevert(FastBridgePool.InsufficientIdleLiquidity.selector);
        pool.fulfill(_id(1), user, 100e18);
    }

    function testHiddenRoundingFavoursThePool() public {
        _deposit(lp1, 3);
        // make the price non-integer: realise a fee of 10 wei, 8 to LPs
        vm.prank(lp2);
        pool.deposit(9_997);
        _fulfill(1, 10_000); // fee 10, paid 9_990
        _settle(1, 10_000);
        assertEq(pool.totalAssets(), 10_008);
        assertEq(pool.totalShares(), 10_000);

        assertEq(pool.convertToShares(10), 9); // 9.99 -> 9
        assertEq(pool.convertToAssets(999), 999); // 999.79 -> 999
        vm.prank(mallory);
        vm.expectRevert(FastBridgePool.ZeroShares.selector);
        pool.deposit(1); // 0.999 shares
        assertEq(_deposit(mallory, 10), 9);
        vm.prank(mallory);
        assertEq(pool.withdraw(9), 9); // paid 10, gets 9 back
        _assertBalanced();
    }

    function testHiddenFeeRounding() public {
        _deposit(lp1, 100_000);
        assertEq(pool.quoteFee(999), 0);
        assertEq(pool.quoteFee(1_999), 1);
        assertEq(_fulfill(1, 999), 999); // no fee on dust
        assertEq(_fulfill(2, 4_999), 4_995); // fee 4, protocol cut 4 * 20% = 0
        _settle(1, 999);
        _settle(2, 4_999);
        assertEq(pool.protocolFees(), 0);
        assertEq(pool.idle(), 100_004);
        _fulfill(3, 5_000); // fee 5, protocol cut 1
        _settle(3, 5_000);
        assertEq(pool.protocolFees(), 1);
        assertEq(pool.idle(), 100_008);
        _assertBalanced();
    }

    function testHiddenWithdrawChecks() public {
        _deposit(lp1, 100e18);
        vm.startPrank(lp2);
        vm.expectRevert(FastBridgePool.ZeroAmount.selector);
        pool.withdraw(0);
        vm.expectRevert(FastBridgePool.InsufficientShares.selector);
        pool.withdraw(1);
        vm.expectRevert(FastBridgePool.ZeroAmount.selector);
        pool.deposit(0);
        vm.stopPrank();
        vm.prank(lp1);
        vm.expectRevert(FastBridgePool.InsufficientShares.selector);
        pool.withdraw(100e18 + 1);
        assertEq(pool.convertToAssets(0), 0);
    }

    function testHiddenEmptyPoolConversions() public {
        assertEq(pool.convertToShares(123), 123);
        assertEq(pool.convertToAssets(123), 0);
        _deposit(lp1, 50e18);
        vm.prank(lp1);
        pool.withdraw(50e18);
        assertEq(pool.totalShares(), 0);
        assertEq(_deposit(lp2, 7e18), 7e18); // pool restarts at 1:1
    }

    function testHiddenProtocolFeesAreSeparate() public {
        _deposit(lp1, 100_000e18);
        _fulfill(1, 10_000e18);
        _settle(1, 10_000e18);

        vm.prank(mallory);
        vm.expectRevert(FastBridgePool.NotOwner.selector);
        pool.withdrawProtocolFees(mallory);
        vm.expectRevert(FastBridgePool.ZeroAddress.selector);
        pool.withdrawProtocolFees(address(0));

        uint256 assetsBefore = pool.totalAssets();
        assertEq(pool.withdrawProtocolFees(address(0xFEE)), 2e18);
        assertEq(usd.balanceOf(address(0xFEE)), 2e18);
        assertEq(pool.totalAssets(), assetsBefore); // LP value untouched
        vm.expectRevert(FastBridgePool.ZeroAmount.selector);
        pool.withdrawProtocolFees(address(0xFEE));

        // LPs can still take out everything that is theirs
        vm.prank(lp1);
        assertEq(pool.withdraw(100_000e18), 100_008e18);
        assertEq(usd.balanceOf(address(pool)), 0);
    }

    function testHiddenProtocolFeesCannotFrontTransfers() public {
        FastBridgePool p = new FastBridgePool(address(usd), relayer, settler, 1_000, 10_000); // all fees to protocol
        vm.prank(lp1);
        usd.approve(address(p), type(uint256).max);
        vm.prank(settler);
        usd.approve(address(p), type(uint256).max);
        vm.prank(lp1);
        p.deposit(900e18);
        vm.prank(relayer);
        p.fulfill(_id(1), user, 1_000e18); // pays 900, fee 100
        vm.prank(settler);
        p.settle(_id(1), user, 1_000e18);
        assertEq(p.protocolFees(), 100e18);
        assertEq(p.idle(), 900e18);
        assertEq(p.totalAssets(), 900e18);

        // the pool holds 1000 tokens but only 900 are LP liquidity
        vm.prank(relayer);
        vm.expectRevert(FastBridgePool.InsufficientIdleLiquidity.selector);
        p.fulfill(_id(2), user, 1_001e18); // would pay 900.9
    }

    function testHiddenInvariantAcrossManyTransfers() public {
        _deposit(lp1, 300_000e18);
        _deposit(lp2, 100_000e18);
        uint256 sumFronted;
        for (uint256 i = 1; i <= 6; i++) {
            sumFronted += _fulfill(i, i * 7_777e18);
        }
        assertEq(pool.outstanding(), sumFronted);
        assertEq(pool.totalAssets(), 400_000e18);
        _settle(2, 2 * 7_777e18);
        _settle(5, 5 * 7_777e18);
        _settle(9, 123e18); // slow path in between
        vm.prank(lp2);
        pool.withdraw(30_000e18);
        _settle(1, 7_777e18);
        _assertBalanced();

        _settle(3, 3 * 7_777e18);
        _settle(4, 4 * 7_777e18);
        _settle(6, 6 * 7_777e18);
        assertEq(pool.outstanding(), 0);
        _assertBalanced();
        // total fee = 0.1% of 21 * 7777 = 163.317; LPs keep 80%
        assertEq(pool.protocolFees(), 32.6634e18);
        vm.prank(lp1);
        uint256 a = pool.withdraw(300_000e18);
        vm.prank(lp2);
        uint256 b = pool.withdraw(70_000e18);
        assertGt(a, 300_000e18);
        assertGt(b, 70_000e18);
        assertLe(usd.balanceOf(address(pool)) - pool.protocolFees(), 2); // at most rounding dust
        assertEq(pool.totalShares(), 0);
    }
}
