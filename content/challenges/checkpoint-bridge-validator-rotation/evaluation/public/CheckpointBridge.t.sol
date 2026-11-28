// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CheckpointBridge.sol";

contract CheckpointBridgeTest is Test {
    address internal v1 = address(0x1001);
    address internal v2 = address(0x1002);
    address internal v3 = address(0x1003);
    address internal v4 = address(0x1004);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function _set4() internal view returns (address[] memory s) {
        s = new address[](4);
        s[0] = v1;
        s[1] = v2;
        s[2] = v3;
        s[3] = v4;
    }

    function _node(bytes32 l, bytes32 r) internal pure returns (bytes32) {
        return keccak256(abi.encode(l, r));
    }

    /// @dev Four withdrawals: nonces 1..4, alice/bob alternating, amounts 1..4 ether.
    function _leaves(CheckpointBridge b) internal view returns (bytes32[4] memory l) {
        l[0] = b.leafOf(1, alice, 1 ether);
        l[1] = b.leafOf(2, bob, 2 ether);
        l[2] = b.leafOf(3, alice, 3 ether);
        l[3] = b.leafOf(4, bob, 4 ether);
    }

    function _root(bytes32[4] memory l) internal pure returns (bytes32) {
        return _node(_node(l[0], l[1]), _node(l[2], l[3]));
    }

    function _proof(bytes32[4] memory l, uint256 index) internal pure returns (bytes32[] memory p) {
        p = new bytes32[](2);
        p[0] = l[index ^ 1];
        p[1] = index < 2 ? _node(l[2], l[3]) : _node(l[0], l[1]);
    }

    function _accept(CheckpointBridge b, uint256 id, bytes32 root) internal {
        vm.prank(v1);
        b.attestCheckpoint(id, root);
        vm.prank(v2);
        b.attestCheckpoint(id, root);
        vm.prank(v3);
        b.attestCheckpoint(id, root);
    }

    CheckpointBridge public bridge;

    function setUp() public {
        bridge = new CheckpointBridge(_set4());
        (bool ok,) = address(bridge).call{value: 100 ether}("");
        assertTrue(ok);
    }

    function testInitialSet() public view {
        assertEq(bridge.epoch(), 1);
        assertEq(bridge.validatorCount(), 4);
        assertEq(bridge.quorum(), 3);
        assertTrue(bridge.isValidator(v1));
        assertTrue(bridge.isValidator(v4));
        assertFalse(bridge.isValidator(alice));
    }

    function testCheckpointAcceptedAtQuorum() public {
        bytes32 root = keccak256("root");
        vm.prank(v1);
        bridge.attestCheckpoint(1, root);
        vm.prank(v2);
        bridge.attestCheckpoint(1, root);
        assertEq(bridge.checkpointVotes(1, root), 2);
        assertEq(bridge.checkpointRoot(1), bytes32(0));
        vm.prank(v4);
        bridge.attestCheckpoint(1, root);
        assertEq(bridge.checkpointRoot(1), root);
    }

    function testNonValidatorCannotAttest() public {
        vm.prank(alice);
        vm.expectRevert(CheckpointBridge.NotValidator.selector);
        bridge.attestCheckpoint(1, keccak256("root"));
    }

    function testWithdrawWithInclusionProof() public {
        bytes32[4] memory l = _leaves(bridge);
        _accept(bridge, 1, _root(l));

        bytes32[] memory p = _proof(l, 2);
        assertTrue(bridge.verifyProof(_root(l), l[2], 2, p));
        bridge.withdraw(1, 2, 3, alice, 3 ether, p);
        assertEq(alice.balance, 3 ether);
        assertTrue(bridge.withdrawn(3));

        vm.expectRevert(CheckpointBridge.AlreadyWithdrawn.selector);
        bridge.withdraw(1, 2, 3, alice, 3 ether, p);
    }

    function testWrongAmountFailsProof() public {
        bytes32[4] memory l = _leaves(bridge);
        _accept(bridge, 1, _root(l));
        bytes32[] memory p = _proof(l, 0);
        vm.expectRevert(CheckpointBridge.InvalidProof.selector);
        bridge.withdraw(1, 0, 1, alice, 2 ether, p);
    }

    function testRotationReplacesSet() public {
        address[] memory next = new address[](2);
        next[0] = address(0x2001);
        next[1] = address(0x2002);
        bytes32 h = bridge.rotationHash(2, next);
        assertEq(h, keccak256(abi.encode(uint256(2), next)));

        vm.prank(v1);
        bridge.attestRotation(next);
        vm.prank(v2);
        bridge.attestRotation(next);
        assertEq(bridge.rotationVotes(h), 2);
        assertEq(bridge.epoch(), 1);
        vm.prank(v3);
        bridge.attestRotation(next);

        assertEq(bridge.epoch(), 2);
        assertEq(bridge.validatorCount(), 2);
        assertEq(bridge.quorum(), 2);
        assertTrue(bridge.isValidator(address(0x2001)));
        assertFalse(bridge.isValidator(v1));
    }
}
