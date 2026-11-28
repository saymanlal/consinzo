// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CanonicalBridgeRouter.sol";

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

    function transferFrom(address from, address to, uint256 amount) external virtual returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

/// @dev Burns 1% of every transferFrom, like a fee-on-transfer token.
contract TaxedERC20 is MockERC20 {
    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        uint256 tax = amount / 100;
        balanceOf[to] += amount - tax;
        totalSupply -= tax;
        return true;
    }
}

contract CanonicalBridgeRouterHiddenTest is Test {
    uint256 internal constant CHAIN_A = 10;
    uint256 internal constant CHAIN_B = 137;
    bytes32 internal constant REMOTE_A = keccak256("usd-on-a");
    bytes32 internal constant REMOTE_B = keccak256("usd-on-b");
    bytes32 internal constant REMOTE_W = keccak256("weth-remote");
    bytes32 internal constant DEST = bytes32(uint256(0xD357));

    CanonicalBridgeRouter public router;
    MockERC20 public usd;
    MockERC20 public weth;
    address public relayer = address(0x4E1A);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        router = new CanonicalBridgeRouter(relayer);
        usd = new MockERC20();
        weth = new MockERC20();
        router.registerRoute(address(usd), CHAIN_A, REMOTE_A, 30);
        router.registerRoute(address(usd), CHAIN_B, REMOTE_B, 100);
        router.registerRoute(address(weth), CHAIN_A, REMOTE_W, 1_000);
        usd.mint(alice, 1_000_000e18);
        weth.mint(alice, 1_000e18);
        vm.startPrank(alice);
        usd.approve(address(router), type(uint256).max);
        weth.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }

    function _out(MockERC20 t, uint256 chain, uint256 amount) internal returns (uint256 n) {
        vm.prank(alice);
        n = router.bridgeOut(address(t), chain, amount, DEST);
    }

    function testHiddenRegisterValidationOrder() public {
        vm.expectRevert(CanonicalBridgeRouter.ZeroAddress.selector);
        router.registerRoute(address(0), 0, bytes32(0), 5_000);
        vm.expectRevert(CanonicalBridgeRouter.InvalidChain.selector);
        router.registerRoute(address(weth), 0, bytes32(0), 5_000);
        uint256 here = block.chainid;
        vm.expectRevert(CanonicalBridgeRouter.InvalidChain.selector);
        router.registerRoute(address(weth), here, REMOTE_W, 0);
        vm.expectRevert(CanonicalBridgeRouter.InvalidRemoteToken.selector);
        router.registerRoute(address(weth), CHAIN_B, bytes32(0), 5_000);
        vm.expectRevert(CanonicalBridgeRouter.FeeTooHigh.selector);
        router.registerRoute(address(usd), CHAIN_A, REMOTE_A, 1_001);
        vm.expectRevert(CanonicalBridgeRouter.RouteExists.selector);
        router.registerRoute(address(usd), CHAIN_A, keccak256("other"), 0);
        vm.expectRevert(CanonicalBridgeRouter.RemoteTokenTaken.selector);
        router.registerRoute(address(weth), CHAIN_B, REMOTE_B, 0);
    }

    function testHiddenSameRemoteIdOnAnotherChainAllowed() public {
        router.registerRoute(address(weth), CHAIN_B, REMOTE_W, 1_000);
        assertEq(router.localTokenOf(CHAIN_B, REMOTE_W), address(weth));
        assertEq(router.localTokenOf(CHAIN_A, REMOTE_W), address(weth));
        (bytes32 remote, uint256 fee) = router.routeOf(address(weth), CHAIN_B);
        assertEq(remote, REMOTE_W);
        assertEq(fee, 1_000);
        (remote, fee) = router.routeOf(address(weth), 999);
        assertEq(remote, bytes32(0));
        assertEq(fee, 0);
    }

    function testHiddenOwnerOnlyFunctions() public {
        vm.startPrank(alice);
        vm.expectRevert(CanonicalBridgeRouter.NotOwner.selector);
        router.registerRoute(address(0), 0, bytes32(0), 0);
        vm.expectRevert(CanonicalBridgeRouter.NotOwner.selector);
        router.setRouteFee(address(usd), CHAIN_A, 0);
        vm.expectRevert(CanonicalBridgeRouter.NotOwner.selector);
        router.setRelayer(alice);
        vm.expectRevert(CanonicalBridgeRouter.NotOwner.selector);
        router.withdrawFees(address(usd), CHAIN_A, alice);
        vm.stopPrank();
    }

    function testHiddenSetRouteFeeAppliesToLaterTransfersOnly() public {
        _out(usd, CHAIN_A, 10_000e18); // 0.30% -> 30
        router.setRouteFee(address(usd), CHAIN_A, 1_000);
        assertEq(router.accruedFees(address(usd), CHAIN_A), 30e18);
        _out(usd, CHAIN_A, 10_000e18); // 10% -> 1000
        assertEq(router.accruedFees(address(usd), CHAIN_A), 1_030e18);
        assertEq(router.lockedLiquidity(address(usd), CHAIN_A), 18_970e18);

        vm.expectRevert(CanonicalBridgeRouter.FeeTooHigh.selector);
        router.setRouteFee(address(usd), CHAIN_A, 1_001);
        vm.expectRevert(CanonicalBridgeRouter.RouteNotFound.selector);
        router.setRouteFee(address(weth), CHAIN_B, 5_000);
    }

    function testHiddenFeeRoundsDown() public {
        _out(usd, CHAIN_A, 333); // 333 * 30 / 10000 = 0.999 -> 0
        assertEq(router.accruedFees(address(usd), CHAIN_A), 0);
        assertEq(router.lockedLiquidity(address(usd), CHAIN_A), 333);
        _out(usd, CHAIN_A, 667); // 2.001 -> 2
        assertEq(router.accruedFees(address(usd), CHAIN_A), 2);
        assertEq(router.lockedLiquidity(address(usd), CHAIN_A), 998);
        (uint256 net, uint256 fee) = router.quote(address(usd), CHAIN_B, 199);
        assertEq(fee, 1);
        assertEq(net, 198);
        vm.expectRevert(CanonicalBridgeRouter.RouteNotFound.selector);
        router.quote(address(weth), CHAIN_B, 1);
    }

    function testHiddenBridgeOutValidationOrder() public {
        vm.startPrank(alice);
        vm.expectRevert(CanonicalBridgeRouter.RouteNotFound.selector);
        router.bridgeOut(address(weth), CHAIN_B, 0, bytes32(0));
        vm.expectRevert(CanonicalBridgeRouter.ZeroAmount.selector);
        router.bridgeOut(address(weth), CHAIN_A, 0, bytes32(0));
        vm.expectRevert(CanonicalBridgeRouter.ZeroAddress.selector);
        router.bridgeOut(address(weth), CHAIN_A, 1, bytes32(0));
        vm.stopPrank();
        assertEq(router.outboundNonce(CHAIN_A), 0);
    }

    function testHiddenNoncesArePerChainAcrossTokens() public {
        assertEq(_out(usd, CHAIN_A, 1e18), 1);
        assertEq(_out(weth, CHAIN_A, 1e18), 2);
        assertEq(_out(usd, CHAIN_B, 1e18), 1);
        assertEq(_out(usd, CHAIN_A, 1e18), 3);
        assertEq(router.outboundNonce(CHAIN_A), 3);
        assertEq(router.outboundNonce(CHAIN_B), 1);
    }

    function testHiddenRoutesAreIsolated() public {
        _out(usd, CHAIN_A, 10_000e18); // locks 9970 towards A
        _out(usd, CHAIN_B, 100e18); // locks 99 towards B

        // Chain B claims more than was ever locked towards it. The router holds enough
        // tokens in total, but they back chain A.
        vm.prank(relayer);
        vm.expectRevert(CanonicalBridgeRouter.InsufficientRouteLiquidity.selector);
        router.bridgeIn(CHAIN_B, REMOTE_B, bob, 99e18 + 1, 1);

        vm.prank(relayer);
        router.bridgeIn(CHAIN_B, REMOTE_B, bob, 99e18, 1);
        assertEq(router.lockedLiquidity(address(usd), CHAIN_B), 0);
        assertEq(router.lockedLiquidity(address(usd), CHAIN_A), 9_970e18);
        assertEq(usd.balanceOf(bob), 99e18);
    }

    function testHiddenFeesNeverPayInboundTransfers() public {
        _out(weth, CHAIN_A, 100e18); // fee 10, locked 90
        vm.prank(relayer);
        vm.expectRevert(CanonicalBridgeRouter.InsufficientRouteLiquidity.selector);
        router.bridgeIn(CHAIN_A, REMOTE_W, bob, 90e18 + 1, 1);
        assertFalse(router.inboundProcessed(CHAIN_A, 1));

        vm.prank(relayer);
        router.bridgeIn(CHAIN_A, REMOTE_W, bob, 90e18, 1);
        assertEq(weth.balanceOf(address(router)), 10e18);
        assertEq(router.accruedFees(address(weth), CHAIN_A), 10e18);
    }

    function testHiddenBridgeInValidationOrder() public {
        _out(usd, CHAIN_A, 1_000e18);
        vm.startPrank(relayer);
        vm.expectRevert(CanonicalBridgeRouter.RouteNotFound.selector);
        router.bridgeIn(CHAIN_B, REMOTE_A, address(0), 0, 1);
        vm.expectRevert(CanonicalBridgeRouter.ZeroAddress.selector);
        router.bridgeIn(CHAIN_A, REMOTE_A, address(0), 0, 1);
        vm.expectRevert(CanonicalBridgeRouter.ZeroAmount.selector);
        router.bridgeIn(CHAIN_A, REMOTE_A, bob, 0, 1);
        router.bridgeIn(CHAIN_A, REMOTE_A, bob, 1e18, 1);
        // replay is reported even when the amount would also exceed liquidity
        vm.expectRevert(CanonicalBridgeRouter.AlreadyProcessed.selector);
        router.bridgeIn(CHAIN_A, REMOTE_A, bob, 5_000e18, 1);
        vm.stopPrank();
    }

    function testHiddenInboundNoncesPerChainAnyOrder() public {
        _out(usd, CHAIN_A, 1_000e18);
        _out(usd, CHAIN_B, 1_000e18);
        vm.startPrank(relayer);
        router.bridgeIn(CHAIN_A, REMOTE_A, bob, 1e18, 9);
        router.bridgeIn(CHAIN_A, REMOTE_A, bob, 1e18, 3);
        router.bridgeIn(CHAIN_B, REMOTE_B, bob, 1e18, 9); // same nonce, other chain
        vm.expectRevert(CanonicalBridgeRouter.AlreadyProcessed.selector);
        router.bridgeIn(CHAIN_A, REMOTE_A, bob, 1e18, 3);
        vm.stopPrank();
        assertEq(usd.balanceOf(bob), 3e18);
        assertFalse(router.inboundProcessed(CHAIN_B, 3));
    }

    function testHiddenRelayerRotation() public {
        _out(usd, CHAIN_A, 1_000e18);
        router.setRelayer(bob);
        vm.prank(relayer);
        vm.expectRevert(CanonicalBridgeRouter.NotRelayer.selector);
        router.bridgeIn(CHAIN_A, REMOTE_A, bob, 1e18, 1);
        vm.prank(bob);
        router.bridgeIn(CHAIN_A, REMOTE_A, alice, 1e18, 1);
        assertEq(router.lockedLiquidity(address(usd), CHAIN_A), 996e18);
    }

    function testHiddenWithdrawFeesPerRouteOnly() public {
        _out(usd, CHAIN_A, 10_000e18); // fee 30
        _out(usd, CHAIN_B, 10_000e18); // fee 100

        vm.expectRevert(CanonicalBridgeRouter.ZeroAddress.selector);
        router.withdrawFees(address(usd), CHAIN_A, address(0));

        assertEq(router.withdrawFees(address(usd), CHAIN_A, bob), 30e18);
        assertEq(router.accruedFees(address(usd), CHAIN_B), 100e18);
        vm.expectRevert(CanonicalBridgeRouter.ZeroAmount.selector);
        router.withdrawFees(address(usd), CHAIN_A, bob);
        assertEq(router.withdrawFees(address(usd), CHAIN_B, bob), 100e18);
        assertEq(usd.balanceOf(bob), 130e18);

        // everything left in the router is locked liquidity
        uint256 locked = router.lockedLiquidity(address(usd), CHAIN_A) + router.lockedLiquidity(address(usd), CHAIN_B);
        assertEq(usd.balanceOf(address(router)), locked);
    }

    function testHiddenFeeOnTransferTokenBooksReceivedAmount() public {
        TaxedERC20 taxed = new TaxedERC20();
        router.registerRoute(address(taxed), CHAIN_A, keccak256("taxed"), 100); // 1%
        taxed.mint(alice, 10_000e18);
        vm.startPrank(alice);
        taxed.approve(address(router), type(uint256).max);
        router.bridgeOut(address(taxed), CHAIN_A, 10_000e18, DEST);
        vm.stopPrank();

        // 9900 arrived: fee 99, locked 9801
        assertEq(taxed.balanceOf(address(router)), 9_900e18);
        assertEq(router.accruedFees(address(taxed), CHAIN_A), 99e18);
        assertEq(router.lockedLiquidity(address(taxed), CHAIN_A), 9_801e18);

        router.withdrawFees(address(taxed), CHAIN_A, bob);
        vm.prank(relayer);
        router.bridgeIn(CHAIN_A, keccak256("taxed"), bob, 9_801e18, 1);
        assertEq(taxed.balanceOf(address(router)), 0);
    }

    function testHiddenSolvencyAfterMixedFlow() public {
        _out(usd, CHAIN_A, 12_345e18);
        _out(usd, CHAIN_B, 6_789e18);
        vm.startPrank(relayer);
        router.bridgeIn(CHAIN_A, REMOTE_A, bob, 2_000e18, 1);
        router.bridgeIn(CHAIN_B, REMOTE_B, bob, 3_000e18, 1);
        vm.stopPrank();
        router.withdrawFees(address(usd), CHAIN_B, bob);
        _out(usd, CHAIN_B, 11e18);

        uint256 owed = router.lockedLiquidity(address(usd), CHAIN_A) + router.lockedLiquidity(address(usd), CHAIN_B)
            + router.accruedFees(address(usd), CHAIN_A) + router.accruedFees(address(usd), CHAIN_B);
        assertEq(usd.balanceOf(address(router)), owed);
    }
}
