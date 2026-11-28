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

interface IExecute {
    function execute(uint256 proposalId, address[] calldata targets, uint256[] calldata values, bytes[] calldata calldatas)
        external;
}

/// Target that tries to execute the same proposal again from inside its own action.
contract ReentrantTarget {
    address public receiver;
    uint256 public proposalId;
    uint256 public hits;
    bool public reentrySucceeded;
    bytes4 public reentryError;

    function arm(address receiver_, uint256 proposalId_) external {
        receiver = receiver_;
        proposalId = proposalId_;
    }

    function poke() external {
        hits += 1;
        address[] memory t = new address[](1);
        uint256[] memory v = new uint256[](1);
        bytes[] memory c = new bytes[](1);
        t[0] = address(this);
        c[0] = abi.encodeWithSelector(this.poke.selector);
        (bool ok, bytes memory ret) =
            receiver.call(abi.encodeWithSelector(IExecute.execute.selector, proposalId, t, v, c));
        reentrySucceeded = ok;
        if (!ok && ret.length >= 4) {
            bytes4 sel;
            assembly {
                sel := mload(add(ret, 32))
            }
            reentryError = sel;
        }
    }
}

contract EtherSink {
    uint256 public received;

    receive() external payable {
        received += msg.value;
    }
}
contract GovernanceReceiverHiddenTest is Test {
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

    function _state(uint256 id) internal view returns (uint256) {
        return uint256(receiver.state(id));
    }

    function testHiddenConstructorValidation() public {
        vm.expectRevert(GovernanceReceiver.ZeroAddress.selector);
        new GovernanceReceiver(address(0), HOME_CHAIN, governor, guardian, DELAY);
        vm.expectRevert(GovernanceReceiver.ZeroAddress.selector);
        new GovernanceReceiver(address(messenger), HOME_CHAIN, address(0), guardian, DELAY);
        vm.expectRevert(GovernanceReceiver.InvalidDelay.selector);
        new GovernanceReceiver(address(messenger), HOME_CHAIN, governor, guardian, 1 hours - 1);
        vm.expectRevert(GovernanceReceiver.InvalidDelay.selector);
        new GovernanceReceiver(address(messenger), HOME_CHAIN, governor, guardian, 30 days + 1);

        GovernanceReceiver r = new GovernanceReceiver(address(messenger), 10, governor, address(0), 30 days);
        assertEq(r.guardian(), address(0));
        assertEq(r.remoteChainId(), 10);
        assertEq(r.messenger(), address(messenger));
        assertEq(r.remoteGovernor(), governor);
        assertEq(r.delay(), 30 days);
    }

    function testHiddenUnknownProposalViews() public view {
        assertEq(_state(99), 0);
        assertEq(receiver.etaOf(99), 0);
        assertEq(receiver.actionsHashOf(99), bytes32(0));
    }

    function testHiddenInvalidProposalShapes() public {
        address[] memory t0 = new address[](0);
        uint256[] memory v0 = new uint256[](0);
        bytes[] memory c0 = new bytes[](0);
        vm.expectRevert(GovernanceReceiver.InvalidProposal.selector);
        messenger.deliver(address(receiver), HOME_CHAIN, governor, abi.encode(uint256(1), t0, v0, c0));

        address[] memory t2 = new address[](2);
        uint256[] memory v1 = new uint256[](1);
        bytes[] memory c2 = new bytes[](2);
        vm.expectRevert(GovernanceReceiver.InvalidProposal.selector);
        messenger.deliver(address(receiver), HOME_CHAIN, governor, abi.encode(uint256(1), t2, v1, c2));

        uint256[] memory v2 = new uint256[](2);
        bytes[] memory c1 = new bytes[](1);
        vm.expectRevert(GovernanceReceiver.InvalidProposal.selector);
        messenger.deliver(address(receiver), HOME_CHAIN, governor, abi.encode(uint256(1), t2, v2, c1));

        assertEq(_state(1), 0);
    }

    function testHiddenUntrustedSourceCheckedBeforePayload() public {
        // a malformed proposal from an untrusted origin reports the origin problem
        address[] memory t0 = new address[](0);
        uint256[] memory v0 = new uint256[](0);
        bytes[] memory c0 = new bytes[](0);
        vm.expectRevert(GovernanceReceiver.UntrustedSource.selector);
        messenger.deliver(address(receiver), HOME_CHAIN, alice, abi.encode(uint256(1), t0, v0, c0));
    }

    function testHiddenProposalIdCannotBeReused() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = _queueSetValue(1, 42);
        uint256 eta = receiver.etaOf(1);

        // redelivery while queued must not push the eta or change the hash
        vm.warp(block.timestamp + 1 days);
        (address[] memory t2, uint256[] memory v2, bytes[] memory c2) =
            _single(address(treasury), 0, abi.encodeWithSelector(Treasury.setValue.selector, 666));
        vm.expectRevert(GovernanceReceiver.ProposalExists.selector);
        messenger.deliver(address(receiver), HOME_CHAIN, governor, abi.encode(uint256(1), t2, v2, c2));
        assertEq(receiver.etaOf(1), eta);
        assertEq(receiver.actionsHashOf(1), keccak256(abi.encode(t, v, c)));

        // after execution
        vm.warp(eta);
        receiver.execute(1, t, v, c);
        vm.expectRevert(GovernanceReceiver.ProposalExists.selector);
        messenger.deliver(address(receiver), HOME_CHAIN, governor, abi.encode(uint256(1), t, v, c));

        // after cancellation
        _queueSetValue(2, 7);
        vm.prank(guardian);
        receiver.cancel(2);
        vm.expectRevert(GovernanceReceiver.ProposalExists.selector);
        messenger.deliver(address(receiver), HOME_CHAIN, governor, abi.encode(uint256(2), t, v, c));
        assertEq(_state(2), 3);
    }

    function testHiddenCannotExecuteTwice() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = _queueSetValue(1, 42);
        vm.warp(block.timestamp + DELAY);
        receiver.execute(1, t, v, c);
        vm.expectRevert(GovernanceReceiver.NotQueued.selector);
        receiver.execute(1, t, v, c);
        assertEq(treasury.callCount(), 1);
    }

    function testHiddenGracePeriodBoundary() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = _queueSetValue(1, 42);
        (address[] memory t2, uint256[] memory v2, bytes[] memory c2) = _queueSetValue(2, 43);
        uint256 eta = receiver.etaOf(1);

        vm.warp(eta + 7 days); // last valid second
        assertEq(_state(1), 1);
        receiver.execute(1, t, v, c);
        assertEq(treasury.value(), 42);

        vm.warp(eta + 7 days + 1);
        assertEq(_state(2), 4);
        vm.expectRevert(GovernanceReceiver.ProposalExpired.selector);
        receiver.execute(2, t2, v2, c2);
        assertEq(treasury.value(), 42);

        // an executed proposal never reads as expired
        assertEq(_state(1), 2);
    }

    function testHiddenExecuteCheckOrder() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = _queueSetValue(1, 42);
        bytes[] memory wrong = new bytes[](1);
        wrong[0] = hex"deadbeef";

        // unknown id beats everything
        vm.expectRevert(GovernanceReceiver.NotQueued.selector);
        receiver.execute(5, t, v, wrong);

        // too early beats mismatch
        vm.expectRevert(GovernanceReceiver.TimelockNotElapsed.selector);
        receiver.execute(1, t, v, wrong);

        // expired beats mismatch
        vm.warp(block.timestamp + DELAY + 7 days + 1);
        vm.expectRevert(GovernanceReceiver.ProposalExpired.selector);
        receiver.execute(1, t, v, wrong);
        c; // silence unused warning
    }

    function testHiddenMismatchVariants() public {
        address[] memory t = new address[](2);
        uint256[] memory v = new uint256[](2);
        bytes[] memory c = new bytes[](2);
        t[0] = address(treasury);
        t[1] = address(treasury);
        c[0] = abi.encodeWithSelector(Treasury.setValue.selector, 1);
        c[1] = abi.encodeWithSelector(Treasury.setValue.selector, 2);
        _queue(1, t, v, c);
        vm.warp(block.timestamp + DELAY);

        // swapped order
        bytes[] memory swapped = new bytes[](2);
        swapped[0] = c[1];
        swapped[1] = c[0];
        vm.expectRevert(GovernanceReceiver.ActionsMismatch.selector);
        receiver.execute(1, t, v, swapped);

        // different value
        uint256[] memory v2 = new uint256[](2);
        v2[1] = 1;
        vm.expectRevert(GovernanceReceiver.ActionsMismatch.selector);
        receiver.execute(1, t, v2, c);

        // different target
        address[] memory t2 = new address[](2);
        t2[0] = address(treasury);
        t2[1] = alice;
        vm.expectRevert(GovernanceReceiver.ActionsMismatch.selector);
        receiver.execute(1, t2, v, c);

        // truncated
        (address[] memory t1, uint256[] memory v1, bytes[] memory c1) = _single(t[0], 0, c[0]);
        vm.expectRevert(GovernanceReceiver.ActionsMismatch.selector);
        receiver.execute(1, t1, v1, c1);

        receiver.execute(1, t, v, c);
        assertEq(treasury.value(), 2); // executed in order
        assertEq(treasury.callCount(), 2);
    }

    function testHiddenFailedActionRevertsEverything() public {
        address[] memory t = new address[](2);
        uint256[] memory v = new uint256[](2);
        bytes[] memory c = new bytes[](2);
        t[0] = address(treasury);
        t[1] = address(treasury);
        c[0] = abi.encodeWithSelector(Treasury.setValue.selector, 5);
        c[1] = abi.encodeWithSelector(Treasury.alwaysFails.selector);
        _queue(1, t, v, c);
        vm.warp(block.timestamp + DELAY);

        vm.expectRevert(abi.encodeWithSelector(GovernanceReceiver.CallFailed.selector, uint256(1)));
        receiver.execute(1, t, v, c);

        assertEq(treasury.value(), 0);
        assertEq(treasury.callCount(), 0);
        assertEq(_state(1), 1); // still queued, not burned by the failed attempt
    }

    function testHiddenEtherActions() public {
        EtherSink sink = new EtherSink();
        vm.deal(address(receiver), 3 ether);

        address[] memory t = new address[](2);
        uint256[] memory v = new uint256[](2);
        bytes[] memory c = new bytes[](2);
        t[0] = address(sink);
        v[0] = 1 ether;
        t[1] = address(treasury);
        v[1] = 0.5 ether;
        c[1] = abi.encodeWithSelector(Treasury.setValue.selector, 9);
        _queue(1, t, v, c);
        vm.warp(block.timestamp + DELAY);
        vm.prank(alice);
        receiver.execute(1, t, v, c);

        assertEq(sink.received(), 1 ether);
        assertEq(address(treasury).balance, 0.5 ether);
        assertEq(address(receiver).balance, 1.5 ether);
    }

    function testHiddenInsufficientEtherFailsAtThatAction() public {
        EtherSink sink = new EtherSink();
        (address[] memory t, uint256[] memory v, bytes[] memory c) = _single(address(sink), 1 ether, "");
        _queue(1, t, v, c);
        vm.warp(block.timestamp + DELAY);
        vm.expectRevert(abi.encodeWithSelector(GovernanceReceiver.CallFailed.selector, uint256(0)));
        receiver.execute(1, t, v, c);

        // funding the receiver through receive() makes the same proposal executable
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        (bool ok,) = address(receiver).call{value: 1 ether}("");
        assertTrue(ok);
        receiver.execute(1, t, v, c);
        assertEq(sink.received(), 1 ether);
    }

    function testHiddenReentrantExecutionBlocked() public {
        ReentrantTarget target = new ReentrantTarget();
        target.arm(address(receiver), 1);
        (address[] memory t, uint256[] memory v, bytes[] memory c) =
            _single(address(target), 0, abi.encodeWithSelector(ReentrantTarget.poke.selector));
        _queue(1, t, v, c);
        vm.warp(block.timestamp + DELAY);

        receiver.execute(1, t, v, c);

        assertEq(target.hits(), 1);
        assertFalse(target.reentrySucceeded());
        assertTrue(target.reentryError() == GovernanceReceiver.NotQueued.selector);
        assertEq(_state(1), 2);
    }

    function testHiddenCancelRules() public {
        _queueSetValue(1, 1);

        vm.prank(alice);
        vm.expectRevert(GovernanceReceiver.NotGuardian.selector);
        receiver.cancel(55); // caller check precedes the status check

        vm.prank(guardian);
        vm.expectRevert(GovernanceReceiver.NotQueued.selector);
        receiver.cancel(55);

        // the remote governor has no cancel power here
        vm.prank(governor);
        vm.expectRevert(GovernanceReceiver.NotGuardian.selector);
        receiver.cancel(1);

        // an expired proposal can still be cancelled explicitly
        vm.warp(block.timestamp + DELAY + 8 days);
        assertEq(_state(1), 4);
        vm.prank(guardian);
        receiver.cancel(1);
        assertEq(_state(1), 3);

        vm.prank(guardian);
        vm.expectRevert(GovernanceReceiver.NotQueued.selector);
        receiver.cancel(1);
    }

    function testHiddenCannotCancelExecuted() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) = _queueSetValue(1, 1);
        vm.warp(block.timestamp + DELAY);
        receiver.execute(1, t, v, c);
        vm.prank(guardian);
        vm.expectRevert(GovernanceReceiver.NotQueued.selector);
        receiver.cancel(1);
    }

    function testHiddenAdminGuards() public {
        vm.startPrank(guardian);
        vm.expectRevert(GovernanceReceiver.OnlySelf.selector);
        receiver.setGuardian(alice);
        vm.expectRevert(GovernanceReceiver.OnlySelf.selector);
        receiver.setRemoteGovernor(alice);
        vm.expectRevert(GovernanceReceiver.OnlySelf.selector);
        receiver.setDelay(1 days);
        vm.stopPrank();

        vm.prank(address(messenger));
        vm.expectRevert(GovernanceReceiver.OnlySelf.selector);
        receiver.setRemoteGovernor(alice);
    }

    function testHiddenInvalidAdminValuesFailTheProposal() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) =
            _single(address(receiver), 0, abi.encodeWithSelector(GovernanceReceiver.setDelay.selector, 30 days + 1));
        _queue(1, t, v, c);
        (address[] memory t2, uint256[] memory v2, bytes[] memory c2) = _single(
            address(receiver), 0, abi.encodeWithSelector(GovernanceReceiver.setRemoteGovernor.selector, address(0))
        );
        _queue(2, t2, v2, c2);
        vm.warp(block.timestamp + DELAY);

        vm.expectRevert(GovernanceReceiver.CallFailed.selector);
        receiver.execute(1, t, v, c);
        vm.expectRevert(GovernanceReceiver.CallFailed.selector);
        receiver.execute(2, t2, v2, c2);
        assertEq(receiver.delay(), DELAY);
        assertEq(receiver.remoteGovernor(), governor);
    }

    function testHiddenDelayChangeDoesNotMoveQueuedProposals() public {
        uint256 t0 = block.timestamp;
        (address[] memory t, uint256[] memory v, bytes[] memory c) =
            _single(address(receiver), 0, abi.encodeWithSelector(GovernanceReceiver.setDelay.selector, 10 days));
        _queue(1, t, v, c);
        (address[] memory ta, uint256[] memory va, bytes[] memory ca) = _queueSetValue(2, 11);

        vm.warp(t0 + DELAY);
        receiver.execute(1, t, v, c);
        assertEq(receiver.delay(), 10 days);

        // proposal 2 keeps its original eta
        assertEq(receiver.etaOf(2), t0 + DELAY);
        receiver.execute(2, ta, va, ca);
        assertEq(treasury.value(), 11);

        // new proposals use the new delay
        _queueSetValue(3, 12);
        assertEq(receiver.etaOf(3), t0 + DELAY + 10 days);
    }

    function testHiddenGovernorRotation() public {
        address newGovernor = address(0x9E3);
        (address[] memory t, uint256[] memory v, bytes[] memory c) = _single(
            address(receiver), 0, abi.encodeWithSelector(GovernanceReceiver.setRemoteGovernor.selector, newGovernor)
        );
        _queue(1, t, v, c);
        // queued by the old governor before the rotation takes effect
        (address[] memory ta, uint256[] memory va, bytes[] memory ca) = _queueSetValue(2, 77);

        vm.warp(block.timestamp + DELAY);
        receiver.execute(1, t, v, c);
        assertEq(receiver.remoteGovernor(), newGovernor);

        // the old governor can no longer queue
        vm.expectRevert(GovernanceReceiver.UntrustedSource.selector);
        messenger.deliver(address(receiver), HOME_CHAIN, governor, abi.encode(uint256(3), ta, va, ca));

        // the new one can
        messenger.deliver(address(receiver), HOME_CHAIN, newGovernor, abi.encode(uint256(3), ta, va, ca));
        assertEq(_state(3), 1);

        // already queued proposals remain executable
        receiver.execute(2, ta, va, ca);
        assertEq(treasury.value(), 77);
    }

    function testHiddenGuardianCanBeRemoved() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c) =
            _single(address(receiver), 0, abi.encodeWithSelector(GovernanceReceiver.setGuardian.selector, address(0)));
        _queue(1, t, v, c);
        _queueSetValue(2, 5);
        vm.warp(block.timestamp + DELAY);
        receiver.execute(1, t, v, c);
        assertEq(receiver.guardian(), address(0));

        vm.prank(guardian);
        vm.expectRevert(GovernanceReceiver.NotGuardian.selector);
        receiver.cancel(2);
    }
}
