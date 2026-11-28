// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LockMintBridge.sol";

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

contract LockMintBridgeTest is Test {
    MockERC20 public canonical;
    SourceVault public vault;
    WrappedToken public wrapped;

    address public relayer = address(0x4E1A);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        canonical = new MockERC20();
        vault = new SourceVault(address(canonical), relayer);
        wrapped = new WrappedToken(relayer);

        canonical.mint(alice, 1_000 ether);
        vm.prank(alice);
        canonical.approve(address(vault), type(uint256).max);
    }

    function testLockPullsTokensAndAssignsNonce() public {
        vm.prank(alice);
        uint256 n1 = vault.lock(100 ether, alice);
        vm.prank(alice);
        uint256 n2 = vault.lock(50 ether, bob);

        assertEq(n1, 1);
        assertEq(n2, 2);
        assertEq(vault.depositCount(), 2);
        assertEq(vault.totalLocked(), 150 ether);
        assertEq(canonical.balanceOf(address(vault)), 150 ether);
        assertEq(canonical.balanceOf(alice), 850 ether);
    }

    function testRelayerMintsWrappedToken() public {
        vm.prank(alice);
        uint256 nonce = vault.lock(100 ether, bob);

        vm.prank(relayer);
        wrapped.mint(nonce, bob, 100 ether);

        assertEq(wrapped.balanceOf(bob), 100 ether);
        assertEq(wrapped.totalSupply(), 100 ether);
        assertTrue(wrapped.processedDeposits(nonce));
    }

    function testMintCannotBeReplayed() public {
        vm.prank(relayer);
        wrapped.mint(1, bob, 100 ether);

        vm.prank(relayer);
        vm.expectRevert(WrappedToken.AlreadyProcessed.selector);
        wrapped.mint(1, bob, 100 ether);
    }

    function testOnlyRelayerMintsAndReleases() public {
        vm.prank(alice);
        vm.expectRevert(WrappedToken.NotRelayer.selector);
        wrapped.mint(1, alice, 1 ether);

        vm.prank(alice);
        vm.expectRevert(SourceVault.NotRelayer.selector);
        vault.release(1, alice, 1 ether);
    }

    function testFullRoundTrip() public {
        vm.prank(alice);
        uint256 depositNonce = vault.lock(100 ether, alice);
        vm.prank(relayer);
        wrapped.mint(depositNonce, alice, 100 ether);

        vm.prank(alice);
        wrapped.transfer(bob, 40 ether);

        vm.prank(bob);
        uint256 burnNonce = wrapped.burn(40 ether, bob);
        assertEq(burnNonce, 1);
        assertEq(wrapped.totalSupply(), 60 ether);

        vm.prank(relayer);
        vault.release(burnNonce, bob, 40 ether);

        assertEq(canonical.balanceOf(bob), 40 ether);
        assertEq(vault.totalLocked(), 60 ether);
        assertEq(vault.totalLocked(), wrapped.totalSupply());
    }
}
