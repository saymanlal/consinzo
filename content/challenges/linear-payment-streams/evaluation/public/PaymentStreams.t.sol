// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PaymentStreams.sol";

contract MockERC20 {
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

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

contract PaymentStreamsTest is Test {
    MockERC20 public token;
    PaymentStreams public streams;
    address public sender = address(0xA11CE);
    address public recipient = address(0xB0B);
    uint256 public t0;

    function setUp() public {
        token = new MockERC20();
        streams = new PaymentStreams();
        token.mint(sender, 10_000 ether);
        vm.prank(sender);
        token.approve(address(streams), type(uint256).max);
        t0 = block.timestamp;
    }

    function _create(uint256 deposit, uint256 start, uint256 stop) internal returns (uint256 id) {
        vm.prank(sender);
        id = streams.createStream(recipient, address(token), deposit, start, stop);
    }

    function testCreateEscrowsDeposit() public {
        uint256 id = _create(1_000 ether, t0, t0 + 1000);
        assertEq(id, 0);
        assertEq(streams.nextStreamId(), 1);
        assertEq(token.balanceOf(address(streams)), 1_000 ether);
        (address s, address r, address tk, uint256 dep, uint256 start, uint256 stop, uint256 withdrawn, bool active) =
            streams.streams(0);
        assertEq(s, sender);
        assertEq(r, recipient);
        assertEq(tk, address(token));
        assertEq(dep, 1_000 ether);
        assertEq(start, t0);
        assertEq(stop, t0 + 1000);
        assertEq(withdrawn, 0);
        assertTrue(active);
    }

    function testLinearAccrual() public {
        uint256 id = _create(1_000 ether, t0, t0 + 1000);
        assertEq(streams.streamedAmount(id), 0);
        vm.warp(t0 + 250);
        assertEq(streams.streamedAmount(id), 250 ether);
        assertEq(streams.withdrawable(id), 250 ether);
        vm.warp(t0 + 5000);
        assertEq(streams.streamedAmount(id), 1_000 ether);
    }

    function testRecipientWithdraws() public {
        uint256 id = _create(1_000 ether, t0, t0 + 1000);
        vm.warp(t0 + 400);
        vm.prank(recipient);
        streams.withdraw(id, 150 ether);
        assertEq(token.balanceOf(recipient), 150 ether);
        assertEq(streams.withdrawable(id), 250 ether);
        vm.warp(t0 + 500);
        assertEq(streams.withdrawable(id), 350 ether);
        assertEq(streams.streamedAmount(id), 500 ether);
    }

    function testCancelSplitsProRata() public {
        uint256 id = _create(1_000 ether, t0, t0 + 1000);
        vm.warp(t0 + 300);
        vm.prank(recipient);
        streams.withdraw(id, 100 ether);
        vm.prank(sender);
        (uint256 toRecipient, uint256 toSender) = streams.cancel(id);
        assertEq(toRecipient, 200 ether);
        assertEq(toSender, 700 ether);
        assertEq(token.balanceOf(recipient), 300 ether);
        assertEq(token.balanceOf(sender), 9_700 ether);
        assertEq(token.balanceOf(address(streams)), 0);
    }

    function testOnlyRecipientWithdraws() public {
        uint256 id = _create(1_000 ether, t0, t0 + 1000);
        vm.warp(t0 + 300);
        vm.prank(sender);
        vm.expectRevert(PaymentStreams.NotAuthorized.selector);
        streams.withdraw(id, 1 ether);
    }
}
