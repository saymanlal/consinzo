// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AllowanceHub.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external virtual returns (bool) {
        _move(from, to, amount);
        return true;
    }

    function _move(address from, address to, uint256 amount) internal {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
    }
}

contract AllowanceHubTest is Test {
    AllowanceHub public hub;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    address public alice = address(0xA11CE);
    address public spender = address(0x5EED);
    address public other = address(0x07E4);
    address public sink = address(0x51CC);
    uint48 public expiry;

    function setUp() public {
        hub = new AllowanceHub();
        tokenA = new MockERC20();
        tokenB = new MockERC20();
        tokenA.mint(alice, 1_000 ether);
        tokenB.mint(alice, 1_000 ether);
        vm.startPrank(alice);
        tokenA.approve(address(hub), type(uint256).max);
        tokenB.approve(address(hub), type(uint256).max);
        vm.stopPrank();
        expiry = uint48(block.timestamp + 1 days);
    }

    function testApproveStoresAllowance() public {
        vm.prank(alice);
        hub.approve(address(tokenA), spender, 100 ether, expiry);
        (uint160 amount, uint48 expiration, uint48 epoch) = hub.allowance(alice, address(tokenA), spender);
        assertEq(uint256(amount), 100 ether);
        assertEq(uint256(expiration), uint256(expiry));
        assertEq(uint256(epoch), 0);
        assertEq(uint256(hub.spendable(alice, address(tokenA), spender)), 100 ether);
    }

    function testSpenderPullsAndAllowanceDecreases() public {
        vm.prank(alice);
        hub.approve(address(tokenA), spender, 100 ether, expiry);

        vm.prank(spender);
        hub.transferFrom(alice, sink, 30 ether, address(tokenA));
        assertEq(tokenA.balanceOf(sink), 30 ether);
        assertEq(tokenA.balanceOf(alice), 970 ether);
        assertEq(uint256(hub.spendable(alice, address(tokenA), spender)), 70 ether);

        vm.prank(spender);
        vm.expectRevert(AllowanceHub.InsufficientAllowance.selector);
        hub.transferFrom(alice, sink, 70 ether + 1, address(tokenA));
    }

    function testAllowanceExpires() public {
        vm.prank(alice);
        hub.approve(address(tokenA), spender, 100 ether, expiry);
        vm.warp(uint256(expiry) + 1);
        assertEq(uint256(hub.spendable(alice, address(tokenA), spender)), 0);
        vm.prank(spender);
        vm.expectRevert(AllowanceHub.AllowanceExpired.selector);
        hub.transferFrom(alice, sink, 1 ether, address(tokenA));
    }

    function testRevokeSingleAllowance() public {
        vm.startPrank(alice);
        hub.approve(address(tokenA), spender, 100 ether, expiry);
        hub.revoke(address(tokenA), spender);
        vm.stopPrank();
        assertEq(uint256(hub.spendable(alice, address(tokenA), spender)), 0);
        vm.prank(spender);
        vm.expectRevert();
        hub.transferFrom(alice, sink, 1 ether, address(tokenA));
    }

    function testRevokeSpenderKillsEveryToken() public {
        vm.startPrank(alice);
        hub.approve(address(tokenA), spender, 100 ether, expiry);
        hub.approve(address(tokenB), spender, 100 ether, expiry);
        uint48 n = hub.revokeSpender(spender);
        vm.stopPrank();
        assertEq(uint256(n), 1);
        assertEq(uint256(hub.nonces(alice, spender)), 1);

        vm.prank(spender);
        vm.expectRevert(AllowanceHub.AllowanceRevoked.selector);
        hub.transferFrom(alice, sink, 1 ether, address(tokenA));
        vm.prank(spender);
        vm.expectRevert(AllowanceHub.AllowanceRevoked.selector);
        hub.transferFrom(alice, sink, 1 ether, address(tokenB));
    }

    function testAllowanceIsPerSpender() public {
        vm.prank(alice);
        hub.approve(address(tokenA), spender, 100 ether, expiry);
        vm.prank(other);
        vm.expectRevert();
        hub.transferFrom(alice, other, 1 ether, address(tokenA));
        assertEq(tokenA.balanceOf(other), 0);
    }

    function testBatchPull() public {
        vm.startPrank(alice);
        hub.approve(address(tokenA), spender, 100 ether, expiry);
        hub.approve(address(tokenB), spender, 50 ether, expiry);
        vm.stopPrank();

        AllowanceHub.Pull[] memory pulls = new AllowanceHub.Pull[](2);
        pulls[0] = AllowanceHub.Pull(alice, address(tokenA), sink, 60 ether);
        pulls[1] = AllowanceHub.Pull(alice, address(tokenB), other, 50 ether);
        vm.prank(spender);
        hub.batchTransferFrom(pulls);

        assertEq(tokenA.balanceOf(sink), 60 ether);
        assertEq(tokenB.balanceOf(other), 50 ether);
        assertEq(uint256(hub.spendable(alice, address(tokenA), spender)), 40 ether);
        assertEq(uint256(hub.spendable(alice, address(tokenB), spender)), 0);
    }
}
