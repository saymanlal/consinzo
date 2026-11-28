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

contract PaymentStreamsHiddenTest is Test {
    MockERC20 public token;
    PaymentStreams public streams;
    address public sender = address(0xA11CE);
    address public recipient = address(0xB0B);
    address public other = address(0xCA201);
    uint256 public t0;

    function setUp() public {
        token = new MockERC20();
        streams = new PaymentStreams();
        token.mint(sender, 10_000 ether);
        vm.prank(sender);
        token.approve(address(streams), type(uint256).max);
        t0 = block.timestamp;
    }

    function _create(address to, uint256 deposit, uint256 start, uint256 stop) internal returns (uint256 id) {
        vm.prank(sender);
        id = streams.createStream(to, address(token), deposit, start, stop);
    }

    function testHiddenCreateValidationOrder() public {
        vm.startPrank(sender);
        vm.expectRevert(PaymentStreams.InvalidRecipient.selector);
        streams.createStream(address(0), address(token), 0, t0, t0);
        vm.expectRevert(PaymentStreams.InvalidRecipient.selector);
        streams.createStream(address(streams), address(token), 1 ether, t0, t0 + 10);
        vm.expectRevert(PaymentStreams.InvalidRecipient.selector);
        streams.createStream(sender, address(token), 1 ether, t0, t0 + 10);
        vm.expectRevert(PaymentStreams.ZeroAmount.selector);
        streams.createStream(recipient, address(token), 0, t0, t0);
        vm.expectRevert(PaymentStreams.InvalidTimes.selector);
        streams.createStream(recipient, address(token), 1 ether, t0 - 1, t0 + 10);
        vm.expectRevert(PaymentStreams.InvalidTimes.selector);
        streams.createStream(recipient, address(token), 1 ether, t0 + 10, t0 + 10);
        vm.expectRevert(PaymentStreams.InvalidTimes.selector);
        streams.createStream(recipient, address(token), 1 ether, t0 + 10, t0 + 9);
        vm.stopPrank();
        assertEq(streams.nextStreamId(), 0);
    }

    function testHiddenRoundingAndFutureStart() public {
        uint256 id = _create(recipient, 100, t0 + 50, t0 + 53);
        vm.warp(t0 + 50);
        assertEq(streams.streamedAmount(id), 0);
        vm.warp(t0 + 51);
        assertEq(streams.streamedAmount(id), 33);
        vm.warp(t0 + 52);
        assertEq(streams.streamedAmount(id), 66);
        vm.prank(recipient);
        vm.expectRevert(PaymentStreams.InsufficientWithdrawable.selector);
        streams.withdraw(id, 67);
        vm.prank(recipient);
        streams.withdraw(id, 66);
        vm.warp(t0 + 53);
        assertEq(streams.withdrawable(id), 34);
    }

    function testHiddenCancelBeforeStartRefundsEverything() public {
        uint256 id = _create(recipient, 500 ether, t0 + 100, t0 + 200);
        vm.warp(t0 + 100);
        vm.prank(recipient);
        (uint256 toRecipient, uint256 toSender) = streams.cancel(id);
        assertEq(toRecipient, 0);
        assertEq(toSender, 500 ether);
        assertEq(token.balanceOf(sender), 10_000 ether);
        assertEq(token.balanceOf(recipient), 0);
    }

    function testHiddenCancelAfterStopPaysRecipient() public {
        uint256 id = _create(recipient, 500 ether, t0, t0 + 100);
        vm.warp(t0 + 60);
        vm.prank(recipient);
        streams.withdraw(id, 300 ether);
        vm.warp(t0 + 1000);
        vm.prank(sender);
        (uint256 toRecipient, uint256 toSender) = streams.cancel(id);
        assertEq(toRecipient, 200 ether);
        assertEq(toSender, 0);
        assertEq(token.balanceOf(recipient), 500 ether);
        assertEq(token.balanceOf(sender), 9_500 ether);
    }

    function testHiddenCancelConservesOddDeposit() public {
        uint256 id = _create(recipient, 1_000 ether + 1, t0, t0 + 7);
        vm.warp(t0 + 3);
        vm.prank(recipient);
        streams.withdraw(id, 1);
        vm.warp(t0 + 5);
        uint256 streamed = streams.streamedAmount(id);
        assertEq(streamed, (uint256(1_000 ether + 1) * 5) / 7);
        vm.prank(sender);
        (uint256 toRecipient, uint256 toSender) = streams.cancel(id);
        assertEq(toRecipient, streamed - 1);
        assertEq(toRecipient + toSender + 1, 1_000 ether + 1);
        assertEq(token.balanceOf(address(streams)), 0);
        assertEq(token.balanceOf(sender) + token.balanceOf(recipient), 10_000 ether);
    }

    function testHiddenInactiveStreamsRejectEverything() public {
        vm.expectRevert(PaymentStreams.StreamNotActive.selector);
        streams.streamedAmount(0);
        vm.prank(other);
        vm.expectRevert(PaymentStreams.StreamNotActive.selector);
        streams.cancel(7);

        uint256 id = _create(recipient, 100 ether, t0, t0 + 100);
        vm.warp(t0 + 50);
        vm.prank(sender);
        streams.cancel(id);
        vm.prank(sender);
        vm.expectRevert(PaymentStreams.StreamNotActive.selector);
        streams.cancel(id);
        vm.prank(recipient);
        vm.expectRevert(PaymentStreams.StreamNotActive.selector);
        streams.withdraw(id, 1);
        vm.expectRevert(PaymentStreams.StreamNotActive.selector);
        streams.withdrawable(id);
    }

    function testHiddenFullWithdrawalClosesStream() public {
        uint256 id = _create(recipient, 100 ether, t0, t0 + 100);
        vm.warp(t0 + 100);
        vm.prank(recipient);
        streams.withdraw(id, 40 ether);
        vm.prank(recipient);
        streams.withdraw(id, 60 ether);
        (, , , , , , uint256 withdrawn, bool active) = streams.streams(id);
        assertEq(withdrawn, 100 ether);
        assertFalse(active);
        vm.prank(sender);
        vm.expectRevert(PaymentStreams.StreamNotActive.selector);
        streams.cancel(id);
        assertEq(token.balanceOf(recipient), 100 ether);
    }

    function testHiddenStreamsAreIsolatedAndAuthorised() public {
        uint256 a = _create(recipient, 1_000 ether, t0, t0 + 100);
        uint256 b = _create(other, 2_000 ether, t0, t0 + 1000);
        vm.warp(t0 + 100);
        // stream a is fully accrued, stream b only 10%
        vm.prank(other);
        vm.expectRevert(PaymentStreams.NotAuthorized.selector);
        streams.withdraw(a, 1 ether);
        vm.prank(other);
        vm.expectRevert(PaymentStreams.NotAuthorized.selector);
        streams.cancel(a);
        vm.prank(other);
        vm.expectRevert(PaymentStreams.InsufficientWithdrawable.selector);
        streams.withdraw(b, 200 ether + 1);
        vm.prank(other);
        vm.expectRevert(PaymentStreams.ZeroAmount.selector);
        streams.withdraw(b, 0);
        vm.prank(other);
        streams.withdraw(b, 200 ether);
        vm.prank(recipient);
        streams.withdraw(a, 1_000 ether);
        assertEq(token.balanceOf(address(streams)), 1_800 ether);
        vm.prank(other);
        (uint256 toRecipient, uint256 toSender) = streams.cancel(b);
        assertEq(toRecipient, 0);
        assertEq(toSender, 1_800 ether);
        assertEq(token.balanceOf(address(streams)), 0);
    }
}
