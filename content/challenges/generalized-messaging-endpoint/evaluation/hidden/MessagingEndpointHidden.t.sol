// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MessagingEndpoint.sol";

/// @dev Simple application: records what it receives, can be told to fail, can reply.
contract App is IMessageReceiver {
    MessagingEndpoint public endpoint;
    bool public failing;
    bool public replyEnabled;
    uint256 public received;
    uint64 public lastNonce;
    address public lastSender;
    uint256 public lastSrcChain;
    bytes public lastPayload;
    uint64[] public order;

    constructor(MessagingEndpoint endpoint_) {
        endpoint = endpoint_;
    }

    receive() external payable {}

    function setFailing(bool f) external {
        failing = f;
    }

    function setReply(bool r) external {
        replyEnabled = r;
    }

    function orderLength() external view returns (uint256) {
        return order.length;
    }

    function sendMessage(uint256 dst, address to, bytes calldata payload, bool ordered, uint256 value)
        external
        returns (bytes32 id, uint64 nonce)
    {
        return endpoint.send{value: value}(dst, to, payload, ordered, address(0));
    }

    function skipMessage(Packet calldata p) external {
        endpoint.skip(p);
    }

    function onMessage(uint256 srcChainId, address sender, uint64 nonce, bool ordered, bytes calldata payload)
        external
        override
    {
        require(msg.sender == address(endpoint), "only endpoint");
        require(!failing, "app failing");
        received++;
        lastNonce = nonce;
        lastSender = sender;
        lastSrcChain = srcChainId;
        lastPayload = payload;
        order.push(nonce);
        if (replyEnabled) {
            uint256 fee = endpoint.quote(srcChainId, 3);
            endpoint.send{value: fee}(srcChainId, sender, "ack", ordered, address(0));
        }
    }
}

/// @dev Receiver that attacks the endpoint from inside onMessage.
contract ReentrantApp is IMessageReceiver {
    MessagingEndpoint public endpoint;
    Packet internal _target;
    uint8 public mode; // 1 = retry target, 2 = skip target, 3 = retry and require success
    bool public sawReentrancyError;
    bool public innerSucceeded;
    uint256 public received;

    constructor(MessagingEndpoint endpoint_) {
        endpoint = endpoint_;
    }

    function arm(uint8 mode_, Packet calldata target) external {
        mode = mode_;
        _target = target;
    }

    function onMessage(uint256, address, uint64, bool, bytes calldata payload) external override {
        require(keccak256(payload) != keccak256("fail"), "told to fail");
        received++;
        if (mode == 1 || mode == 3) {
            try endpoint.retry(_target) {
                innerSucceeded = true;
            } catch (bytes memory err) {
                sawReentrancyError = bytes4(err) == MessagingEndpoint.Reentrancy.selector;
            }
        } else if (mode == 2) {
            try endpoint.skip(_target) {
                innerSucceeded = true;
            } catch (bytes memory err) {
                sawReentrancyError = bytes4(err) == MessagingEndpoint.Reentrancy.selector;
            }
        }
    }
}

/// @dev Writes many fresh storage slots: needs a lot of gas but succeeds when it gets it.
contract HeavyApp is IMessageReceiver {
    mapping(uint256 => uint256) public slots;
    uint256 public received;
    uint256 public writes;

    constructor(uint256 writes_) {
        writes = writes_;
    }

    function onMessage(uint256, address, uint64 nonce, bool, bytes calldata) external override {
        for (uint256 i = 0; i < writes; i++) {
            slots[uint256(nonce) * 1_000 + i] = 1;
        }
        received++;
    }
}

/// @dev Reverts with a very large payload.
contract BombApp is IMessageReceiver {
    function onMessage(uint256, address, uint64, bool, bytes calldata) external pure override {
        assembly {
            revert(0, 20000)
        }
    }
}

/// @dev Refund target that sends another message from inside the refund.
contract RefundReenterer {
    MessagingEndpoint public endpoint;
    address public to;
    uint256 public dst;
    uint64 public innerNonce;
    bool public done;

    constructor(MessagingEndpoint endpoint_, uint256 dst_, address to_) {
        endpoint = endpoint_;
        dst = dst_;
        to = to_;
    }

    function go(uint256 value) external returns (uint64 outerNonce) {
        (, outerNonce) = endpoint.send{value: value}(dst, to, "outer", false, address(this));
    }

    receive() external payable {
        if (!done) {
            done = true;
            uint256 fee = endpoint.quote(dst, 5);
            (, innerNonce) = endpoint.send{value: fee}(dst, to, "inner", false, address(this));
        }
    }
}

contract RefundRejector {
    receive() external payable {
        revert("no refunds");
    }
}

contract MessagingEndpointHiddenTest is Test {
    uint256 internal constant CHAIN_A = 1;
    uint256 internal constant CHAIN_B = 2;
    uint256 internal constant EXEC_GAS = 300_000;
    uint256 internal constant BASE_FEE = 0.001 ether;
    uint256 internal constant BYTE_FEE = 1 gwei;

    MessagingEndpoint public epA;
    MessagingEndpoint public epB;
    App public appA;
    App public appB;
    address public relayer = address(0x4E1A);
    address public alice = address(0xA11CE);

    receive() external payable {}

    function _base() internal {
        epA = new MessagingEndpoint(CHAIN_A, relayer, EXEC_GAS);
        epB = new MessagingEndpoint(CHAIN_B, relayer, EXEC_GAS);
        epA.setFee(CHAIN_B, uint120(BASE_FEE), uint120(BYTE_FEE));
        epB.setFee(CHAIN_A, uint120(BASE_FEE), uint120(BYTE_FEE));
        appA = new App(epA);
        appB = new App(epB);
        vm.deal(address(appA), 10 ether);
        vm.deal(address(appB), 10 ether);
        vm.deal(alice, 10 ether);
    }

    /// @dev Packet from `sender` on chain A to `receiver` on chain B.
    function _pkt(address sender, address receiver, uint64 nonce, bool ordered, bytes memory payload)
        internal
        pure
        returns (Packet memory)
    {
        return Packet(CHAIN_A, sender, CHAIN_B, receiver, nonce, ordered, payload);
    }

    function _deliverB(Packet memory p) internal {
        vm.prank(relayer);
        epB.deliver(p);
    }

    function _statusB(Packet memory p) internal view returns (MessagingEndpoint.Status) {
        return epB.status(epB.packetId(p));
    }

    function setUp() public {
        _base();
    }

    // ------------------------------------------------------------ configuration

    function testHiddenConstructorAndFeeValidation() public {
        vm.expectRevert(MessagingEndpoint.InvalidConfig.selector);
        new MessagingEndpoint(0, relayer, EXEC_GAS);
        vm.expectRevert(MessagingEndpoint.InvalidConfig.selector);
        new MessagingEndpoint(CHAIN_A, address(0), EXEC_GAS);
        vm.expectRevert(MessagingEndpoint.InvalidConfig.selector);
        new MessagingEndpoint(CHAIN_A, relayer, 0);

        vm.expectRevert(MessagingEndpoint.InvalidConfig.selector);
        epA.setFee(0, 1, 1);
        vm.expectRevert(MessagingEndpoint.InvalidConfig.selector);
        epA.setFee(CHAIN_A, 1, 1);
        vm.prank(alice);
        vm.expectRevert(MessagingEndpoint.NotOwner.selector);
        epA.setFee(CHAIN_B, 0, 0);

        vm.expectRevert(MessagingEndpoint.UnsupportedChain.selector);
        epA.quote(77, 10);
        epA.setFee(77, 0, 0); // free route is allowed once enabled
        assertEq(epA.quote(77, 10), 0);
        (bool enabled,,) = epA.feeConfig(77);
        assertTrue(enabled);
    }

    // ------------------------------------------------------------------ sending

    function testHiddenSendValidationOrder() public {
        vm.startPrank(alice);
        vm.expectRevert(MessagingEndpoint.UnsupportedChain.selector);
        epA.send{value: 0}(77, address(0), "x", false, address(0));
        vm.expectRevert(MessagingEndpoint.ZeroAddress.selector);
        epA.send{value: 0}(CHAIN_B, address(0), "x", false, address(0));
        uint256 fee = BASE_FEE + BYTE_FEE;
        vm.expectRevert(MessagingEndpoint.InsufficientFee.selector);
        epA.send{value: fee - 1}(CHAIN_B, address(appB), "x", false, address(0));
        epA.send{value: fee}(CHAIN_B, address(appB), "x", false, address(0)); // exact fee, no refund
        vm.stopPrank();
        assertEq(alice.balance, 10 ether - fee);
        assertEq(uint256(epA.outboundNonce(alice, CHAIN_B, address(appB), false)), 1);
    }

    function testHiddenNonceSpacesAreSeparate() public {
        vm.startPrank(alice);
        (, uint64 a) = epA.send{value: 1 ether}(CHAIN_B, address(appB), "x", false, address(0));
        (, uint64 b) = epA.send{value: 1 ether}(CHAIN_B, address(appB), "x", false, address(0));
        (, uint64 c) = epA.send{value: 1 ether}(CHAIN_B, address(appB), "x", true, address(0));
        (, uint64 d) = epA.send{value: 1 ether}(CHAIN_B, address(appA), "x", false, address(0));
        vm.stopPrank();
        (, uint64 e) = appA.sendMessage(CHAIN_B, address(appB), "x", false, 1 ether);
        assertEq(uint256(a), 1);
        assertEq(uint256(b), 2);
        assertEq(uint256(c), 1);
        assertEq(uint256(d), 1);
        assertEq(uint256(e), 1);
        // ordered and unordered packets with the same nonce have different ids
        bytes32 idU = epA.packetId(_pkt(alice, address(appB), 1, false, "x"));
        bytes32 idO = epA.packetId(_pkt(alice, address(appB), 1, true, "x"));
        assertTrue(idU != idO);
        assertEq(idU, keccak256(abi.encode(CHAIN_A, alice, CHAIN_B, address(appB), uint64(1), false, keccak256("x"))));
    }

    function testHiddenRefundTargets() public {
        uint256 fee = epA.quote(CHAIN_B, 1);
        address bob = address(0xB0B);
        vm.prank(alice);
        epA.send{value: 1 ether}(CHAIN_B, address(appB), "x", false, bob);
        assertEq(bob.balance, 1 ether - fee);
        assertEq(alice.balance, 9 ether);

        RefundRejector rej = new RefundRejector();
        vm.startPrank(alice);
        vm.expectRevert(MessagingEndpoint.RefundFailed.selector);
        epA.send{value: 1 ether}(CHAIN_B, address(appB), "x", false, address(rej));
        // with the exact fee nothing is refunded, so the same target is harmless
        epA.send{value: fee}(CHAIN_B, address(appB), "x", false, address(rej));
        vm.stopPrank();
        assertEq(uint256(epA.outboundNonce(alice, CHAIN_B, address(appB), false)), 2);
        assertEq(epA.collectedFees(), 2 * fee);
        assertEq(address(epA).balance, 2 * fee);
    }

    function testHiddenSendFromRefundCallback() public {
        RefundReenterer r = new RefundReenterer(epA, CHAIN_B, address(appB));
        vm.deal(address(r), 5 ether);
        uint64 outer = r.go(1 ether);
        assertEq(uint256(outer), 1);
        assertEq(uint256(r.innerNonce()), 2); // nested send got its own nonce
        uint256 fee = epA.quote(CHAIN_B, 5);
        assertEq(epA.collectedFees(), 2 * fee);
        assertEq(address(epA).balance, 2 * fee);
        assertEq(address(r).balance, 5 ether - 2 * fee);
    }

    function testHiddenWithdrawFees() public {
        vm.prank(alice);
        epA.send{value: 1 ether}(CHAIN_B, address(appB), "abcd", false, address(0));
        uint256 fee = BASE_FEE + 4 * BYTE_FEE;

        vm.prank(alice);
        vm.expectRevert(MessagingEndpoint.NotOwner.selector);
        epA.withdrawFees(alice);
        vm.expectRevert(MessagingEndpoint.ZeroAddress.selector);
        epA.withdrawFees(address(0));
        RefundRejector rej = new RefundRejector();
        vm.expectRevert(MessagingEndpoint.TransferFailed.selector);
        epA.withdrawFees(address(rej));

        address treasury = address(0x7EA5);
        assertEq(epA.withdrawFees(treasury), fee);
        assertEq(treasury.balance, fee);
        assertEq(epA.collectedFees(), 0);
        vm.expectRevert(MessagingEndpoint.NothingToWithdraw.selector);
        epA.withdrawFees(treasury);
    }

    // ----------------------------------------------------------------- delivery

    function testHiddenDeliverValidationOrder() public {
        Packet memory wrong = Packet(CHAIN_A, address(appA), 99, address(appB), 1, false, "x");
        vm.prank(alice);
        vm.expectRevert(MessagingEndpoint.NotRelayer.selector);
        epB.deliver(wrong);
        vm.prank(relayer);
        vm.expectRevert(MessagingEndpoint.WrongChain.selector);
        epB.deliver(wrong);
        // a packet for chain B is not accepted by chain A's endpoint
        Packet memory p = _pkt(address(appA), address(appB), 1, false, "x");
        vm.prank(relayer);
        vm.expectRevert(MessagingEndpoint.WrongChain.selector);
        epA.deliver(p);
        assertTrue(_statusB(p) == MessagingEndpoint.Status.None);
    }

    function testHiddenReplyFromInsideOnMessage() public {
        appB.setReply(true);
        Packet memory p = _pkt(address(appA), address(appB), 1, true, "ping");
        _deliverB(p);
        assertTrue(_statusB(p) == MessagingEndpoint.Status.Delivered);
        // appB sent "ack" back to appA on the ordered channel B -> A
        assertEq(uint256(epB.outboundNonce(address(appB), CHAIN_A, address(appA), true)), 1);
        assertEq(epB.collectedFees(), BASE_FEE + 3 * BYTE_FEE);

        Packet memory ack = Packet(CHAIN_B, address(appB), CHAIN_A, address(appA), 1, true, "ack");
        vm.prank(relayer);
        epA.deliver(ack);
        assertEq(appA.received(), 1);
        assertEq(keccak256(appA.lastPayload()), keccak256("ack"));
        assertEq(appA.lastSender(), address(appB));
    }

    function testHiddenOrderedFailureBlocksChannelUntilRetry() public {
        Packet memory p1 = _pkt(address(appA), address(appB), 1, true, "1");
        Packet memory p2 = _pkt(address(appA), address(appB), 2, true, "2");
        Packet memory p3 = _pkt(address(appA), address(appB), 3, true, "3");
        _deliverB(p1);
        appB.setFailing(true);
        _deliverB(p2);
        assertTrue(_statusB(p2) == MessagingEndpoint.Status.Failed);
        assertEq(epB.blockedBy(CHAIN_A, address(appA), address(appB)), epB.packetId(p2));
        assertEq(uint256(epB.inboundNonce(CHAIN_A, address(appA), address(appB))), 2);
        appB.setFailing(false);

        // p3 must wait even though the app is healthy again
        vm.prank(relayer);
        vm.expectRevert(MessagingEndpoint.ChannelBlocked.selector);
        epB.deliver(p3);
        // the failed packet cannot be delivered a second time either
        vm.prank(relayer);
        vm.expectRevert(MessagingEndpoint.AlreadyDelivered.selector);
        epB.deliver(p2);

        epB.retry(p2);
        assertEq(epB.blockedBy(CHAIN_A, address(appA), address(appB)), bytes32(0));
        _deliverB(p3);
        assertEq(appB.orderLength(), 3);
        assertEq(uint256(appB.order(0)), 1);
        assertEq(uint256(appB.order(1)), 2);
        assertEq(uint256(appB.order(2)), 3);
    }

    function testHiddenBlockedChannelDoesNotAffectOthers() public {
        appB.setFailing(true);
        _deliverB(_pkt(address(appA), address(appB), 1, true, "1")); // blocks appA -> appB ordered
        appB.setFailing(false);

        // unordered traffic between the same pair
        _deliverB(_pkt(address(appA), address(appB), 1, false, "u"));
        // ordered traffic from another sender to the same receiver
        _deliverB(_pkt(alice, address(appB), 1, true, "other"));
        // ordered traffic from another source chain with the same sender address
        Packet memory other = Packet(77, address(appA), CHAIN_B, address(appB), 1, true, "c");
        _deliverB(other);
        assertEq(appB.received(), 3);
        assertEq(uint256(epB.inboundNonce(CHAIN_A, alice, address(appB))), 1);
        assertEq(uint256(epB.inboundNonce(77, address(appA), address(appB))), 1);
        assertEq(epB.blockedBy(CHAIN_A, alice, address(appB)), bytes32(0));
    }

    function testHiddenRetryFailingAgainChangesNothing() public {
        Packet memory p = _pkt(address(appA), address(appB), 1, true, "1");
        appB.setFailing(true);
        _deliverB(p);
        vm.expectRevert(MessagingEndpoint.RetryFailed.selector);
        epB.retry(p);
        assertTrue(_statusB(p) == MessagingEndpoint.Status.Failed);
        assertEq(epB.blockedBy(CHAIN_A, address(appA), address(appB)), epB.packetId(p));

        appB.setFailing(false);
        epB.retry(p);
        vm.expectRevert(MessagingEndpoint.NotFailed.selector);
        epB.retry(p); // executed once only
        assertEq(appB.received(), 1);
    }

    function testHiddenRetryRequiresExactPacket() public {
        Packet memory p = _pkt(address(appA), address(appB), 1, false, "pay 1");
        appB.setFailing(true);
        _deliverB(p);
        appB.setFailing(false);

        Packet memory forged = _pkt(address(appA), address(appB), 1, false, "pay 1000");
        vm.expectRevert(MessagingEndpoint.NotFailed.selector);
        epB.retry(forged);
        Packet memory never = _pkt(address(appA), address(appB), 2, false, "pay 1");
        vm.expectRevert(MessagingEndpoint.NotFailed.selector);
        epB.retry(never);
        assertEq(appB.received(), 0);
    }

    function testHiddenSkipByReceiverOnly() public {
        Packet memory p1 = _pkt(address(appA), address(appB), 1, true, "1");
        Packet memory p2 = _pkt(address(appA), address(appB), 2, true, "2");
        appB.setFailing(true);
        _deliverB(p1);
        appB.setFailing(false);

        vm.prank(relayer);
        vm.expectRevert(MessagingEndpoint.NotReceiver.selector);
        epB.skip(p1);
        vm.expectRevert(MessagingEndpoint.NotReceiver.selector);
        epB.skip(p1); // not the owner either
        // receiver cannot skip something that has not failed
        vm.expectRevert(MessagingEndpoint.NotFailed.selector);
        appB.skipMessage(p2);

        appB.skipMessage(p1);
        assertTrue(_statusB(p1) == MessagingEndpoint.Status.Skipped);
        assertEq(epB.blockedBy(CHAIN_A, address(appA), address(appB)), bytes32(0));

        // skipped is terminal
        vm.expectRevert(MessagingEndpoint.NotFailed.selector);
        epB.retry(p1);
        vm.prank(relayer);
        vm.expectRevert(MessagingEndpoint.AlreadyDelivered.selector);
        epB.deliver(p1);
        vm.expectRevert(MessagingEndpoint.NotFailed.selector);
        appB.skipMessage(p1);

        _deliverB(p2); // channel continues at the next nonce
        assertEq(appB.received(), 1);
        assertEq(uint256(appB.lastNonce()), 2);
    }

    function testHiddenReceiverWithoutCodeFails() public {
        address eoa = address(0xE0A);
        Packet memory p = _pkt(address(appA), eoa, 1, true, "x");
        _deliverB(p);
        assertTrue(_statusB(p) == MessagingEndpoint.Status.Failed); // not silently "delivered"
        assertEq(epB.blockedBy(CHAIN_A, address(appA), eoa), epB.packetId(p));
        vm.expectRevert(MessagingEndpoint.RetryFailed.selector);
        epB.retry(p);
        vm.prank(eoa);
        epB.skip(p);
        assertTrue(_statusB(p) == MessagingEndpoint.Status.Skipped);
    }

    // --------------------------------------------------------------------- gas

    function testHiddenReceiverOutOfGasIsAFailureNotARevert() public {
        HeavyApp heavy = new HeavyApp(30); // needs about 670k gas, the endpoint gives 300k
        Packet memory p = _pkt(address(appA), address(heavy), 1, false, "x");
        _deliverB(p);
        assertTrue(_statusB(p) == MessagingEndpoint.Status.Failed);
        assertEq(heavy.received(), 0);
        // and the endpoint is still usable afterwards
        _deliverB(_pkt(address(appA), address(appB), 1, false, "y"));
        assertEq(appB.received(), 1);
    }

    function testHiddenRevertBombDoesNotBreakDelivery() public {
        BombApp bomb = new BombApp();
        Packet memory p = _pkt(address(appA), address(bomb), 1, true, "x");
        _deliverB(p);
        assertTrue(_statusB(p) == MessagingEndpoint.Status.Failed);
    }

    function testHiddenCallerCannotStarveReceiver() public {
        MessagingEndpoint big = new MessagingEndpoint(CHAIN_B, relayer, 3_000_000);
        HeavyApp heavy = new HeavyApp(100); // about 2.25M gas: fine with 3M
        Packet memory p = _pkt(address(appA), address(heavy), 1, true, "x");

        // 3.05M is less than 3M * 64/63 + reserve: the receiver could not get its 3M
        vm.prank(relayer);
        vm.expectRevert(MessagingEndpoint.InsufficientGas.selector);
        big.deliver{gas: 3_050_000}(p);
        assertTrue(big.status(big.packetId(p)) == MessagingEndpoint.Status.None);
        assertEq(uint256(big.inboundNonce(CHAIN_A, address(appA), address(heavy))), 0);

        vm.prank(relayer);
        big.deliver(p); // with enough gas it is simply delivered
        assertTrue(big.status(big.packetId(p)) == MessagingEndpoint.Status.Delivered);
        assertEq(heavy.received(), 1);
    }

    function testHiddenRetryAlsoChecksGas() public {
        MessagingEndpoint big = new MessagingEndpoint(CHAIN_B, relayer, 3_000_000);
        ReentrantApp app = new ReentrantApp(big);
        Packet memory bad = _pkt(address(appA), address(app), 1, false, "fail");
        vm.prank(relayer);
        big.deliver(bad);
        assertTrue(big.status(big.packetId(bad)) == MessagingEndpoint.Status.Failed);
        vm.expectRevert(MessagingEndpoint.InsufficientGas.selector);
        big.retry{gas: 3_050_000}(bad);
    }

    // -------------------------------------------------------------- reentrancy

    function testHiddenReceiverCannotRetryDuringDelivery() public {
        ReentrantApp app = new ReentrantApp(epB);
        // a previously failed message for the same app
        Packet memory failed = _pkt(address(appA), address(app), 1, false, "fail");
        _deliverB(failed);
        assertTrue(_statusB(failed) == MessagingEndpoint.Status.Failed);

        app.arm(1, failed);
        Packet memory p = _pkt(address(appA), address(app), 2, false, "go");
        _deliverB(p);
        assertTrue(_statusB(p) == MessagingEndpoint.Status.Delivered);
        assertTrue(app.sawReentrancyError());
        assertFalse(app.innerSucceeded());
        assertTrue(_statusB(failed) == MessagingEndpoint.Status.Failed);
    }

    function testHiddenReceiverCannotSkipDuringDelivery() public {
        ReentrantApp app = new ReentrantApp(epB);
        Packet memory failed = _pkt(address(appA), address(app), 1, true, "fail");
        _deliverB(failed);
        app.arm(2, failed);
        // unordered message to the same app while its ordered channel is blocked
        _deliverB(_pkt(address(appA), address(app), 1, false, "go"));
        assertTrue(app.sawReentrancyError());
        assertFalse(app.innerSucceeded());
        assertTrue(_statusB(failed) == MessagingEndpoint.Status.Failed);
        assertEq(epB.blockedBy(CHAIN_A, address(appA), address(app)), epB.packetId(failed));
    }

    function testHiddenMessageCannotRetryItselfWhileExecuting() public {
        ReentrantApp app = new ReentrantApp(epB);
        Packet memory p = _pkt(address(appA), address(app), 1, false, "go");
        app.arm(3, p); // while p is executing, the app asks the endpoint to retry p
        _deliverB(p);
        assertEq(app.received(), 1); // executed once, not twice
        assertFalse(app.innerSucceeded());
        assertTrue(_statusB(p) == MessagingEndpoint.Status.Delivered);
        vm.expectRevert(MessagingEndpoint.NotFailed.selector);
        epB.retry(p);
    }

    function testHiddenRetriedMessageCannotReenterRetry() public {
        ReentrantApp app = new ReentrantApp(epB);
        Packet memory other = _pkt(address(appA), address(app), 1, false, "fail");
        _deliverB(other);
        MessagingEndpoint.Status st = _statusB(other);
        assertTrue(st == MessagingEndpoint.Status.Failed);
        // "fail" keeps failing, so retrying it reverts and it stays Failed whatever the app tries
        app.arm(1, other);
        vm.expectRevert(MessagingEndpoint.RetryFailed.selector);
        epB.retry(other);
        assertTrue(_statusB(other) == MessagingEndpoint.Status.Failed);
        assertEq(app.received(), 0);
    }

    function testHiddenLockIsReleasedAfterEachCall() public {
        Packet memory p1 = _pkt(address(appA), address(appB), 1, false, "1");
        appB.setFailing(true);
        _deliverB(p1); // failure path
        appB.setFailing(false);
        epB.retry(p1); // lock must be free again
        _deliverB(_pkt(address(appA), address(appB), 2, false, "2"));
        Packet memory bad = _failOnce();
        vm.expectRevert(MessagingEndpoint.RetryFailed.selector);
        epB.retry(bad);
        _deliverB(_pkt(address(appA), address(appB), 3, false, "3")); // free after a reverted retry too
        assertEq(appB.received(), 3);
    }

    function _failOnce() internal returns (Packet memory p) {
        ReentrantApp app = new ReentrantApp(epB);
        p = _pkt(address(appA), address(app), 1, false, "fail");
        _deliverB(p);
    }
}
