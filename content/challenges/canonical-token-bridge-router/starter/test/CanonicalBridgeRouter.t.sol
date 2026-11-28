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

contract CanonicalBridgeRouterTest is Test {
    uint256 internal constant CHAIN_A = 10;
    uint256 internal constant CHAIN_B = 137;
    bytes32 internal constant REMOTE_A = keccak256("usd-on-a");
    bytes32 internal constant REMOTE_B = keccak256("usd-on-b");
    bytes32 internal constant DEST = bytes32(uint256(0xD357));

    CanonicalBridgeRouter public router;
    MockERC20 public usd;
    address public relayer = address(0x4E1A);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        router = new CanonicalBridgeRouter(relayer);
        usd = new MockERC20();
        router.registerRoute(address(usd), CHAIN_A, REMOTE_A, 30); // 0.30%
        router.registerRoute(address(usd), CHAIN_B, REMOTE_B, 0);
        usd.mint(alice, 1_000_000e18);
        vm.prank(alice);
        usd.approve(address(router), type(uint256).max);
    }

    function testRegistryLookups() public view {
        (bytes32 remote, uint256 fee) = router.routeOf(address(usd), CHAIN_A);
        assertEq(remote, REMOTE_A);
        assertEq(fee, 30);
        assertEq(router.localTokenOf(CHAIN_A, REMOTE_A), address(usd));
        assertEq(router.localTokenOf(CHAIN_B, REMOTE_B), address(usd));
        assertEq(router.localTokenOf(CHAIN_B, REMOTE_A), address(0));
        assertEq(router.owner(), address(this));
        assertEq(router.relayer(), relayer);
    }

    function testBridgeOutSplitsFeeAndLiquidity() public {
        vm.prank(alice);
        uint256 nonce = router.bridgeOut(address(usd), CHAIN_A, 10_000e18, DEST);
        assertEq(nonce, 1);
        assertEq(router.accruedFees(address(usd), CHAIN_A), 30e18);
        assertEq(router.lockedLiquidity(address(usd), CHAIN_A), 9_970e18);
        assertEq(usd.balanceOf(address(router)), 10_000e18);
        assertEq(router.outboundNonce(CHAIN_A), 1);
        assertEq(router.outboundNonce(CHAIN_B), 0);
    }

    function testQuoteMatchesBridgeOut() public view {
        (uint256 net, uint256 fee) = router.quote(address(usd), CHAIN_A, 10_000e18);
        assertEq(fee, 30e18);
        assertEq(net, 9_970e18);
        (net, fee) = router.quote(address(usd), CHAIN_B, 5e18);
        assertEq(fee, 0);
        assertEq(net, 5e18);
    }

    function testBridgeInReleasesFromRoute() public {
        vm.prank(alice);
        router.bridgeOut(address(usd), CHAIN_A, 10_000e18, DEST);

        vm.prank(relayer);
        router.bridgeIn(CHAIN_A, REMOTE_A, bob, 4_000e18, 7);
        assertEq(usd.balanceOf(bob), 4_000e18);
        assertEq(router.lockedLiquidity(address(usd), CHAIN_A), 5_970e18);
        assertTrue(router.inboundProcessed(CHAIN_A, 7));
    }

    function testBridgeInReplayRejected() public {
        vm.prank(alice);
        router.bridgeOut(address(usd), CHAIN_A, 10_000e18, DEST);
        vm.prank(relayer);
        router.bridgeIn(CHAIN_A, REMOTE_A, bob, 1e18, 1);
        vm.prank(relayer);
        vm.expectRevert(CanonicalBridgeRouter.AlreadyProcessed.selector);
        router.bridgeIn(CHAIN_A, REMOTE_A, bob, 1e18, 1);
    }

    function testOnlyRelayerCanBridgeIn() public {
        vm.prank(alice);
        router.bridgeOut(address(usd), CHAIN_A, 10_000e18, DEST);
        vm.prank(alice);
        vm.expectRevert(CanonicalBridgeRouter.NotRelayer.selector);
        router.bridgeIn(CHAIN_A, REMOTE_A, alice, 1e18, 1);
    }

    function testWithdrawFees() public {
        vm.prank(alice);
        router.bridgeOut(address(usd), CHAIN_A, 10_000e18, DEST);
        uint256 paid = router.withdrawFees(address(usd), CHAIN_A, bob);
        assertEq(paid, 30e18);
        assertEq(usd.balanceOf(bob), 30e18);
        assertEq(router.accruedFees(address(usd), CHAIN_A), 0);
        assertEq(router.lockedLiquidity(address(usd), CHAIN_A), 9_970e18);
    }
}
