// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CheckpointBridge.sol";

/// @dev Recipient that tries to be paid again from inside the ETH callback.
contract ReentrantRecipient {
    CheckpointBridge public bridge;
    uint256 public checkpointId;
    uint256 public index;
    uint256 public nonce;
    uint256 public amount;
    bytes32[] public proof;
    uint256 public attempts;
    bool public innerSucceeded;

    function arm(CheckpointBridge b, uint256 id, uint256 i, uint256 n, uint256 a, bytes32[] memory p) external {
        bridge = b;
        checkpointId = id;
        index = i;
        nonce = n;
        amount = a;
        proof = p;
    }

    receive() external payable {
        if (attempts == 0) {
            attempts = 1;
            try bridge.withdraw(checkpointId, index, nonce, address(this), amount, proof) {
                innerSucceeded = true;
            } catch {}
        }
    }
}

contract Rejector {
    receive() external payable {
        revert("no");
    }
}

contract CheckpointBridgeHiddenTest is Test {
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

    function _range(uint160 base, uint256 n) internal pure returns (address[] memory s) {
        s = new address[](n);
        for (uint256 i = 0; i < n; i++) {
            s[i] = address(base + uint160(i));
        }
    }

    function _rotate(address[] memory next) internal {
        vm.prank(v1);
        bridge.attestRotation(next);
        vm.prank(v2);
        bridge.attestRotation(next);
        vm.prank(v3);
        bridge.attestRotation(next);
    }

    function testHiddenQuorumForSeveralSizes() public {
        uint256[6] memory sizes = [uint256(1), 2, 3, 5, 6, 32];
        uint256[6] memory expected = [uint256(1), 2, 3, 4, 5, 22];
        for (uint256 i = 0; i < sizes.length; i++) {
            CheckpointBridge b = new CheckpointBridge(_range(0x5000, sizes[i]));
            assertEq(b.quorum(), expected[i]);
            assertEq(b.validatorCount(), sizes[i]);
        }
    }

    function testHiddenSingleValidatorAcceptsAlone() public {
        CheckpointBridge b = new CheckpointBridge(_range(0x5000, 1));
        vm.prank(address(0x5000));
        b.attestCheckpoint(9, keccak256("r"));
        assertEq(b.checkpointRoot(9), keccak256("r"));
    }

    function testHiddenConstructorSetValidation() public {
        vm.expectRevert(CheckpointBridge.InvalidValidatorSet.selector);
        new CheckpointBridge(new address[](0));
        vm.expectRevert(CheckpointBridge.InvalidValidatorSet.selector);
        new CheckpointBridge(_range(0x5000, 33));
        address[] memory dup = new address[](2);
        dup[0] = v1;
        dup[1] = v1;
        vm.expectRevert(CheckpointBridge.InvalidValidatorSet.selector);
        new CheckpointBridge(dup);
        address[] memory zero = new address[](2);
        zero[0] = address(0);
        zero[1] = v1;
        vm.expectRevert(CheckpointBridge.InvalidValidatorSet.selector);
        new CheckpointBridge(zero);
    }

    function testHiddenEquivocationRejected() public {
        bytes32 a = keccak256("a");
        bytes32 b = keccak256("b");
        vm.startPrank(v1);
        bridge.attestCheckpoint(1, a);
        vm.expectRevert(CheckpointBridge.AlreadyAttested.selector);
        bridge.attestCheckpoint(1, a);
        vm.expectRevert(CheckpointBridge.AlreadyAttested.selector);
        bridge.attestCheckpoint(1, b); // cannot also back a competing root
        bridge.attestCheckpoint(2, b); // other checkpoints are independent
        vm.stopPrank();
        assertEq(bridge.checkpointVotes(1, a), 1);
        assertEq(bridge.checkpointVotes(1, b), 0);
    }

    function testHiddenSplitVotesDoNotAddUp() public {
        bytes32 a = keccak256("a");
        bytes32 b = keccak256("b");
        vm.prank(v1);
        bridge.attestCheckpoint(1, a);
        vm.prank(v2);
        bridge.attestCheckpoint(1, a);
        vm.prank(v3);
        bridge.attestCheckpoint(1, b);
        vm.prank(v4);
        bridge.attestCheckpoint(1, b);
        // all four voted, 2-2: nothing is accepted
        assertEq(bridge.checkpointRoot(1), bytes32(0));
        bytes32[] memory empty = new bytes32[](0);
        vm.expectRevert(CheckpointBridge.UnknownCheckpoint.selector);
        bridge.withdraw(1, 0, 1, alice, 1 ether, empty);
    }

    function testHiddenAcceptedRootIsFinal() public {
        bytes32 a = keccak256("a");
        _accept(bridge, 1, a);
        vm.prank(v4);
        vm.expectRevert(CheckpointBridge.CheckpointFinal.selector);
        bridge.attestCheckpoint(1, keccak256("b"));
        vm.prank(v4);
        vm.expectRevert(CheckpointBridge.CheckpointFinal.selector);
        bridge.attestCheckpoint(1, a);
        assertEq(bridge.checkpointRoot(1), a);
    }

    function testHiddenAttestCheckOrder() public {
        vm.prank(alice);
        vm.expectRevert(CheckpointBridge.NotValidator.selector);
        bridge.attestCheckpoint(1, bytes32(0));
        vm.prank(v1);
        vm.expectRevert(CheckpointBridge.InvalidRoot.selector);
        bridge.attestCheckpoint(1, bytes32(0));
    }

    function testHiddenRotationSetValidation() public {
        vm.prank(alice);
        vm.expectRevert(CheckpointBridge.NotValidator.selector);
        bridge.attestRotation(new address[](0));

        vm.startPrank(v1);
        vm.expectRevert(CheckpointBridge.InvalidValidatorSet.selector);
        bridge.attestRotation(new address[](0));
        address[] memory unsorted = new address[](2);
        unsorted[0] = address(0x2002);
        unsorted[1] = address(0x2001);
        vm.expectRevert(CheckpointBridge.InvalidValidatorSet.selector);
        bridge.attestRotation(unsorted);
        unsorted[1] = address(0x2002);
        vm.expectRevert(CheckpointBridge.InvalidValidatorSet.selector);
        bridge.attestRotation(unsorted); // duplicate
        address[] memory big = _range(0x5000, 33);
        vm.expectRevert(CheckpointBridge.InvalidValidatorSet.selector);
        bridge.attestRotation(big);

        address[] memory ok = _range(0x5000, 32);
        bridge.attestRotation(ok);
        vm.expectRevert(CheckpointBridge.AlreadyAttested.selector);
        bridge.attestRotation(ok);
        // a validator may back a second, different proposal
        bridge.attestRotation(_range(0x6000, 3));
        vm.stopPrank();
        assertEq(bridge.rotationVotes(bridge.rotationHash(2, ok)), 1);
    }

    function testHiddenCompetingRotationsOnlyOneWins() public {
        address[] memory a = _range(0x5000, 3);
        address[] memory b = _range(0x6000, 3);
        vm.prank(v1);
        bridge.attestRotation(a);
        vm.prank(v2);
        bridge.attestRotation(a);
        vm.prank(v3);
        bridge.attestRotation(b);
        vm.prank(v4);
        bridge.attestRotation(b);
        assertEq(bridge.epoch(), 1);
        vm.prank(v1);
        bridge.attestRotation(b);
        assertEq(bridge.epoch(), 2);
        assertTrue(bridge.isValidator(address(0x6000)));
        assertFalse(bridge.isValidator(address(0x5000)));
        // the old set is out; it cannot complete the other proposal
        vm.prank(v3);
        vm.expectRevert(CheckpointBridge.NotValidator.selector);
        bridge.attestRotation(a);
    }

    function testHiddenRemovedValidatorsLosePower() public {
        _rotate(_range(0x5000, 3));
        assertFalse(bridge.isValidator(v1));
        vm.prank(v1);
        vm.expectRevert(CheckpointBridge.NotValidator.selector);
        bridge.attestCheckpoint(1, keccak256("evil"));
        vm.prank(v2);
        vm.expectRevert(CheckpointBridge.NotValidator.selector);
        bridge.attestRotation(_set4());
    }

    function testHiddenCheckpointVotesDoNotSurviveRotation() public {
        // Old set gets a malicious root to 2 of the 3 votes it needs...
        bytes32 evil = keccak256("evil");
        vm.prank(v1);
        bridge.attestCheckpoint(7, evil);
        vm.prank(v2);
        bridge.attestCheckpoint(7, evil);

        // ...then the set rotates to {v3, v4, n1, n2}; v1 and v2 are removed.
        address[] memory next = new address[](4);
        next[0] = v3;
        next[1] = v4;
        next[2] = address(0x2001);
        next[3] = address(0x2002);
        _rotate(next);
        assertEq(bridge.checkpointVotes(7, evil), 0);

        // One vote from the new set must not complete the old tally.
        vm.prank(v3);
        bridge.attestCheckpoint(7, evil);
        assertEq(bridge.checkpointRoot(7), bytes32(0));
        assertEq(bridge.checkpointVotes(7, evil), 1);

        // The new set decides on its own.
        bytes32 good = keccak256("good");
        vm.prank(v4);
        bridge.attestCheckpoint(7, good);
        vm.prank(address(0x2001));
        bridge.attestCheckpoint(7, good);
        vm.prank(address(0x2002));
        bridge.attestCheckpoint(7, good);
        assertEq(bridge.checkpointRoot(7), good);
    }

    function testHiddenCarriedOverValidatorVotesAgain() public {
        bytes32 r = keccak256("r");
        vm.prank(v3);
        bridge.attestCheckpoint(7, r); // epoch 1 vote
        address[] memory next = new address[](2);
        next[0] = v3;
        next[1] = v4;
        _rotate(next);
        vm.prank(v3);
        bridge.attestCheckpoint(7, r); // allowed again in epoch 2
        assertEq(bridge.checkpointRoot(7), bytes32(0));
        vm.prank(v4);
        bridge.attestCheckpoint(7, r);
        assertEq(bridge.checkpointRoot(7), r);
    }

    function testHiddenRotationVotesAreBoundToEpoch() public {
        // Epoch 1: two votes for set X (not enough).
        address[] memory x = new address[](2);
        x[0] = address(0x7001);
        x[1] = address(0x7002);
        vm.prank(v1);
        bridge.attestRotation(x);
        vm.prank(v2);
        bridge.attestRotation(x);

        // Rotate to a set that still contains v1..v3.
        address[] memory same = new address[](3);
        same[0] = v1;
        same[1] = v2;
        same[2] = v3;
        _rotate(same);
        assertEq(bridge.epoch(), 2);
        assertEq(bridge.quorum(), 3);

        // The old two votes for X are gone; X now needs three fresh votes.
        assertEq(bridge.rotationVotes(bridge.rotationHash(3, x)), 0);
        vm.prank(v3);
        bridge.attestRotation(x);
        assertEq(bridge.epoch(), 2);
        vm.prank(v1);
        bridge.attestRotation(x); // v1 may vote again in the new epoch
        vm.prank(v2);
        bridge.attestRotation(x);
        assertEq(bridge.epoch(), 3);
        assertTrue(bridge.isValidator(address(0x7001)));
        assertFalse(bridge.isValidator(v1));
    }

    function testHiddenAcceptedRootsSurviveRotation() public {
        bytes32[4] memory l = _leaves(bridge);
        _accept(bridge, 1, _root(l));
        _rotate(_range(0x5000, 3));
        bridge.withdraw(1, 1, 2, bob, 2 ether, _proof(l, 1));
        assertEq(bob.balance, 2 ether);
    }

    function testHiddenProofIsPositional() public {
        bytes32[4] memory l = _leaves(bridge);
        bytes32 root = _root(l);
        _accept(bridge, 1, root);

        for (uint256 i = 0; i < 4; i++) {
            assertTrue(bridge.verifyProof(root, l[i], i, _proof(l, i)));
            assertFalse(bridge.verifyProof(root, l[i], i ^ 1, _proof(l, i)));
            assertFalse(bridge.verifyProof(root, l[i], i ^ 2, _proof(l, i)));
        }
        // index beyond the tree: the low bits match position 1 but the position does not exist
        assertFalse(bridge.verifyProof(root, l[1], 5, _proof(l, 1)));
        assertFalse(bridge.verifyProof(root, l[0], 4, _proof(l, 0)));

        bytes32[] memory p = _proof(l, 1);
        vm.expectRevert(CheckpointBridge.InvalidProof.selector);
        bridge.withdraw(1, 5, 2, bob, 2 ether, p);
        vm.expectRevert(CheckpointBridge.InvalidProof.selector);
        bridge.withdraw(1, 0, 2, bob, 2 ether, p);
        vm.expectRevert(CheckpointBridge.InvalidProof.selector);
        bridge.withdraw(1, 1, 2, alice, 2 ether, p); // redirected recipient
        vm.expectRevert(CheckpointBridge.InvalidProof.selector);
        bridge.withdraw(1, 1, 3, bob, 2 ether, p); // other nonce
        assertEq(bob.balance, 0);
    }

    function testHiddenProofLengthMatters() public {
        bytes32[4] memory l = _leaves(bridge);
        bytes32 root = _root(l);
        bytes32[] memory empty = new bytes32[](0);
        assertFalse(bridge.verifyProof(root, l[0], 0, empty));
        assertTrue(bridge.verifyProof(l[0], l[0], 0, empty)); // single-leaf tree
        assertFalse(bridge.verifyProof(l[0], l[0], 1, empty));

        // An inner node is not a leaf: presenting the left subtree as a "leaf" at index 0
        // with a one-element proof must not be reachable through leafOf.
        bytes32 inner = _node(l[0], l[1]);
        bytes32[] memory shortProof = new bytes32[](1);
        shortProof[0] = _node(l[2], l[3]);
        assertTrue(bridge.verifyProof(root, inner, 0, shortProof)); // pure hashing agrees...
        assertTrue(bridge.leafOf(uint256(l[0]), address(uint160(uint256(l[1]))), 0) != inner); // ...but no withdrawal hashes to it

        bytes32 expected = keccak256(bytes.concat(keccak256(abi.encode(uint256(1), alice, uint256(1 ether)))));
        assertEq(l[0], expected);
    }

    function testHiddenSameNonceInTwoCheckpointsPaidOnce() public {
        bytes32[4] memory l = _leaves(bridge);
        _accept(bridge, 1, _root(l));
        // Checkpoint 2 is a single-leaf tree that includes withdrawal nonce 1 again.
        _accept(bridge, 2, l[0]);
        bytes32[] memory empty = new bytes32[](0);

        bridge.withdraw(2, 0, 1, alice, 1 ether, empty);
        bytes32[] memory p = _proof(l, 0);
        vm.expectRevert(CheckpointBridge.AlreadyWithdrawn.selector);
        bridge.withdraw(1, 0, 1, alice, 1 ether, p);
        assertEq(alice.balance, 1 ether);
    }

    function testHiddenWithdrawCheckOrder() public {
        bytes32[4] memory l = _leaves(bridge);
        bytes32[] memory p = _proof(l, 0);
        vm.expectRevert(CheckpointBridge.UnknownCheckpoint.selector);
        bridge.withdraw(1, 0, 1, alice, 1 ether, p);
        _accept(bridge, 1, _root(l));
        bridge.withdraw(1, 0, 1, alice, 1 ether, p);
        // a paid nonce is reported as such even with a broken proof
        vm.expectRevert(CheckpointBridge.AlreadyWithdrawn.selector);
        bridge.withdraw(1, 3, 1, bob, 9 ether, p);
    }

    function testHiddenReentrantRecipientPaidOnce() public {
        ReentrantRecipient r = new ReentrantRecipient();
        bytes32 leaf = bridge.leafOf(50, address(r), 10 ether);
        bytes32 other = bridge.leafOf(51, alice, 1 ether);
        bytes32 root = _node(other, leaf);
        _accept(bridge, 1, root);
        bytes32[] memory p = new bytes32[](1);
        p[0] = other;
        r.arm(bridge, 1, 1, 50, 10 ether, p);

        bridge.withdraw(1, 1, 50, address(r), 10 ether, p);
        assertEq(r.attempts(), 1);
        assertFalse(r.innerSucceeded());
        assertEq(address(r).balance, 10 ether);
        assertEq(address(bridge).balance, 90 ether);
    }

    function testHiddenFailedPaymentLeavesNonceOpen() public {
        Rejector rej = new Rejector();
        bytes32 leaf = bridge.leafOf(60, address(rej), 1 ether);
        bytes32 big = bridge.leafOf(61, alice, 500 ether);
        _accept(bridge, 1, _node(leaf, big));
        bytes32[] memory p = new bytes32[](1);

        p[0] = big;
        vm.expectRevert(CheckpointBridge.TransferFailed.selector);
        bridge.withdraw(1, 0, 60, address(rej), 1 ether, p);
        assertFalse(bridge.withdrawn(60));

        // more than the bridge holds: fails now, succeeds after funding
        p[0] = leaf;
        vm.expectRevert(CheckpointBridge.TransferFailed.selector);
        bridge.withdraw(1, 1, 61, alice, 500 ether, p);
        assertFalse(bridge.withdrawn(61));
        (bool ok,) = address(bridge).call{value: 400 ether}("");
        assertTrue(ok);
        bridge.withdraw(1, 1, 61, alice, 500 ether, p);
        assertEq(alice.balance, 500 ether);
    }
}
