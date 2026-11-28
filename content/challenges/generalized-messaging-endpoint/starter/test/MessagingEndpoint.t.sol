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

contract MessagingEndpointTest is Test {
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

    function testQuoteAndConfig() public view {
        assertEq(epA.localChainId(), CHAIN_A);
        assertEq(epA.relayer(), relayer);
        assertEq(epA.executionGas(), EXEC_GAS);
        assertEq(epA.owner(), address(this));
        assertEq(epA.quote(CHAIN_B, 0), BASE_FEE);
        assertEq(epA.quote(CHAIN_B, 100), BASE_FEE + 100 * BYTE_FEE);
    }

    function testSendAssignsNonceAndCollectsFee() public {
        uint256 fee = epA.quote(CHAIN_B, 5);
        (bytes32 id, uint64 nonce) = appA.sendMessage(CHAIN_B, address(appB), "hello", false, fee);
        assertEq(uint256(nonce), 1);
        assertEq(id, epA.packetId(_pkt(address(appA), address(appB), 1, false, "hello")));
        assertEq(epA.collectedFees(), fee);
        assertEq(uint256(epA.outboundNonce(address(appA), CHAIN_B, address(appB), false)), 1);
        assertEq(uint256(epA.outboundNonce(address(appA), CHAIN_B, address(appB), true)), 0);
    }

    function testEndToEndDelivery() public {
        uint256 fee = epA.quote(CHAIN_B, 5);
        (, uint64 nonce) = appA.sendMessage(CHAIN_B, address(appB), "hello", true, fee);
        Packet memory p = _pkt(address(appA), address(appB), nonce, true, "hello");
        _deliverB(p);

        assertTrue(_statusB(p) == MessagingEndpoint.Status.Delivered);
        assertEq(appB.received(), 1);
        assertEq(appB.lastSender(), address(appA));
        assertEq(appB.lastSrcChain(), CHAIN_A);
        assertEq(keccak256(appB.lastPayload()), keccak256("hello"));
        assertEq(uint256(epB.inboundNonce(CHAIN_A, address(appA), address(appB))), 1);
    }

    function testOverpaymentIsRefunded() public {
        uint256 fee = epA.quote(CHAIN_B, 2);
        vm.prank(alice);
        epA.send{value: 1 ether}(CHAIN_B, address(appB), "hi", false, address(0));
        assertEq(alice.balance, 10 ether - fee);
        assertEq(epA.collectedFees(), fee);
        assertEq(address(epA).balance, fee);
    }

    function testOrderedChannelRejectsGaps() public {
        Packet memory p2 = _pkt(address(appA), address(appB), 2, true, "two");
        vm.prank(relayer);
        vm.expectRevert(MessagingEndpoint.OutOfOrder.selector);
        epB.deliver(p2);

        _deliverB(_pkt(address(appA), address(appB), 1, true, "one"));
        _deliverB(p2);
        assertEq(appB.received(), 2);
    }

    function testUnorderedChannelAcceptsAnyOrder() public {
        _deliverB(_pkt(address(appA), address(appB), 3, false, "c"));
        _deliverB(_pkt(address(appA), address(appB), 1, false, "a"));
        assertEq(appB.received(), 2);
        assertEq(uint256(appB.order(0)), 3);
        assertEq(uint256(epB.inboundNonce(CHAIN_A, address(appA), address(appB))), 0);
    }

    function testFailedDeliveryIsRecordedAndRetried() public {
        Packet memory p = _pkt(address(appA), address(appB), 1, false, "x");
        appB.setFailing(true);
        _deliverB(p); // does not revert
        assertTrue(_statusB(p) == MessagingEndpoint.Status.Failed);
        assertEq(appB.received(), 0);

        appB.setFailing(false);
        vm.prank(alice); // anyone may retry
        epB.retry(p);
        assertTrue(_statusB(p) == MessagingEndpoint.Status.Delivered);
        assertEq(appB.received(), 1);
    }

    function testReplayRejected() public {
        Packet memory p = _pkt(address(appA), address(appB), 1, false, "x");
        _deliverB(p);
        vm.prank(relayer);
        vm.expectRevert(MessagingEndpoint.AlreadyDelivered.selector);
        epB.deliver(p);
    }
}
