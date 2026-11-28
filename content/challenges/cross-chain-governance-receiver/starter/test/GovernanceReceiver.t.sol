// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GovernanceReceiver.sol";

/// Stands in for the bridge endpoint on the receiving chain.
contract MockMessenger {
    function deliver(address receiver, uint256 sourceChainId, address sourceSender, bytes memory payload) external {
        GovernanceReceiver(payable(receiver)).receiveMessage(sourceChainId, sourceSender, payload);
    }
}

/// A contract owned by the DAO on this chain.
contract Treasury {
    address public owner;
    uint256 public value;
    uint256 public callCount;

    constructor(address owner_) {
        owner = owner_;
    }

    function setValue(uint256 v) external payable {
        require(msg.sender == owner, "not owner");
        value = v;
        callCount += 1;
    }

    function alwaysFails() external pure {
        revert("nope");
    }
}

contract GovernanceReceiverTest is Test {
    uint256 internal constant HOME_CHAIN = 1;
    uint256 internal constant DELAY = 2 days;

    MockMessenger public messenger;
    GovernanceReceiver public receiver;
    Treasury public treasury;

    address public governor = address(0x60BE4);
    address public guardian = address(0x6A4D);
    address public alice = address(0xA11CE);

    function _base() internal {
        messenger = new MockMessenger();
        receiver = new GovernanceReceiver(address(messenger), HOME_CHAIN, governor, guardian, DELAY);
        treasury = new Treasury(address(receiver));
    }

    function _single(address target, uint256 value, bytes memory data)
        internal
        pure
        returns (address[] memory t, uint256[] memory v, bytes[] memory c)
    {
        t = new address[](1);
        v = new uint256[](1);
        c = new bytes[](1);
        t[0] = target;
        v[0] = value;
        c[0] = data;
    }

    function _queue(uint256 id, address[] memory t, uint256[] memory v, bytes[] memory c) internal {
        messenger.deliver(address(receiver), HOME_CHAIN, governor, abi.encode(id, t, v, c));
    }

    function _queueSetValue(uint256 id, uint256 newValue)
        internal
        returns (address[] memory t, uint256[] memory v, bytes[] memory c)
    {
        (t, v, c) = _single(address(treasury), 0, abi.encodeWithSelector(Treasury.setValue.selector, newValue));
        _queue(id, t, v, c);
    }

    function setUp() public {
        _base();
    }

    function testQueueStoresHashAndEta() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = _queueSetValue(1, 42);

        assertEq(uint256(receiver.state(1)), uint256(GovernanceReceiver.State.Queued));
        assertEq(receiver.etaOf(1), block.timestamp + DELAY);
        assertEq(receiver.actionsHashOf(1), keccak256(abi.encode(t, v, c)));
        assertEq(receiver.hashActions(t, v, c), keccak256(abi.encode(t, v, c)));
    }

    function testExecuteAfterDelay() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = _queueSetValue(1, 42);

        vm.warp(block.timestamp + DELAY);
        vm.prank(alice); // anyone may execute
        receiver.execute(1, t, v, c);

        assertEq(treasury.value(), 42);
        assertEq(uint256(receiver.state(1)), uint256(GovernanceReceiver.State.Executed));
    }

    function testCannotExecuteBeforeDelay() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = _queueSetValue(1, 42);

        vm.warp(block.timestamp + DELAY - 1);
        vm.expectRevert(GovernanceReceiver.TimelockNotElapsed.selector);
        receiver.execute(1, t, v, c);
    }

    function testRejectsUntrustedOrigins() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) =
            _single(address(treasury), 0, abi.encodeWithSelector(Treasury.setValue.selector, 1));
        bytes memory payload = abi.encode(uint256(1), t, v, c);

        // not the messenger
        vm.prank(governor);
        vm.expectRevert(GovernanceReceiver.NotMessenger.selector);
        receiver.receiveMessage(HOME_CHAIN, governor, payload);

        // wrong sender on the right chain
        vm.expectRevert(GovernanceReceiver.UntrustedSource.selector);
        messenger.deliver(address(receiver), HOME_CHAIN, alice, payload);

        // right sender address on the wrong chain
        vm.expectRevert(GovernanceReceiver.UntrustedSource.selector);
        messenger.deliver(address(receiver), 137, governor, payload);

        assertEq(uint256(receiver.state(1)), uint256(GovernanceReceiver.State.None));
    }

    function testExecuteRequiresMatchingActions() public {
        (address[] memory t, uint256[] memory v,) = _queueSetValue(1, 42);
        bytes[] memory other = new bytes[](1);
        other[0] = abi.encodeWithSelector(Treasury.setValue.selector, 43);

        vm.warp(block.timestamp + DELAY);
        vm.expectRevert(GovernanceReceiver.ActionsMismatch.selector);
        receiver.execute(1, t, v, other);
    }

    function testGuardianCanCancel() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = _queueSetValue(1, 42);

        vm.prank(alice);
        vm.expectRevert(GovernanceReceiver.NotGuardian.selector);
        receiver.cancel(1);

        vm.prank(guardian);
        receiver.cancel(1);
        assertEq(uint256(receiver.state(1)), uint256(GovernanceReceiver.State.Cancelled));

        vm.warp(block.timestamp + DELAY);
        vm.expectRevert(GovernanceReceiver.NotQueued.selector);
        receiver.execute(1, t, v, c);
    }

    function testAdminFunctionsOnlyThroughProposals() public {
        vm.prank(governor);
        vm.expectRevert(GovernanceReceiver.OnlySelf.selector);
        receiver.setDelay(1 hours);

        (address[] memory t, uint256[] memory v, bytes[] memory c) =
            _single(address(receiver), 0, abi.encodeWithSelector(GovernanceReceiver.setDelay.selector, 1 hours));
        _queue(7, t, v, c);
        vm.warp(block.timestamp + DELAY);
        receiver.execute(7, t, v, c);
        assertEq(receiver.delay(), 1 hours);
    }
}
