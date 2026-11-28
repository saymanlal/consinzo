// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MerkleDrop.sol";

contract DropToken {
    mapping(address => uint256) public balanceOf;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

abstract contract DropFixture is Test {
    MerkleDrop public drop;
    DropToken public token;

    address[4] internal who = [address(0xA11CE), address(0xB0B), address(0xCA201), address(0xDA7E)];
    uint96[4] internal amt = [uint96(100e18), 250e18, 40e18, 610e18];
    bytes32[4] internal leaf;
    bytes32 internal n01;
    bytes32 internal n23;
    bytes32 internal root;

    function _deploy() internal {
        token = new DropToken();
        drop = new MerkleDrop(IERC20Min(address(token)));
        // Generously funded, so that a claim never fails merely for lack of tokens.
        token.mint(address(drop), type(uint96).max);

        for (uint256 i = 0; i < 4; i++) leaf[i] = drop.leafHash(i, who[i], amt[i]);
        n01 = drop.hashPair(leaf[0], leaf[1]);
        n23 = drop.hashPair(leaf[2], leaf[3]);
        root = drop.hashPair(n01, n23);
        drop.setRoot(root);
    }

    function _proof(uint256 i) internal view returns (bytes32[] memory p) {
        p = new bytes32[](2);
        p[0] = leaf[i ^ 1];
        p[1] = i < 2 ? n23 : n01;
    }

    /// Reinterprets the 64-byte preimage of node hashPair(a, b) as (index, account, amount).
    function _asLeaf(bytes32 a, bytes32 b) internal pure returns (uint256 index, address account, uint96 amount) {
        (bytes32 lo, bytes32 hi) = a < b ? (a, b) : (b, a);
        index = uint256(lo);
        account = address(bytes20(hi));
        amount = uint96(uint256(hi));
    }
}

contract MerkleDropHiddenTest is DropFixture {
    function setUp() public {
        _deploy();
    }

    function testHiddenOtherInternalNodeRejected() public {
        (uint256 index, address account, uint96 amount) = _asLeaf(leaf[2], leaf[3]);
        bytes32[] memory p = new bytes32[](1);
        p[0] = n01;
        vm.expectRevert(MerkleDrop.InvalidProof.selector);
        drop.claim(index, account, amount, p);
        assertEq(token.balanceOf(account), 0);
        assertEq(token.balanceOf(address(drop)), type(uint96).max);
    }

    function testHiddenRootPreimageRejectedWithEmptyProof() public {
        (uint256 index, address account, uint96 amount) = _asLeaf(n01, n23);
        bytes32[] memory p = new bytes32[](0);
        vm.expectRevert(MerkleDrop.InvalidProof.selector);
        drop.claim(index, account, amount, p);
        assertEq(token.balanceOf(account), 0);
        assertFalse(drop.claimed(index));
    }

    function testHiddenLeafIsNotASingleHashOfSixtyFourBytes() public {
        for (uint256 i = 0; i < 4; i++) {
            assertTrue(leaf[i] != keccak256(abi.encodePacked(i, who[i], amt[i])));
        }
        // and never equal to the node built from the same 64 bytes
        bytes32 a = bytes32(uint256(7));
        bytes32 b = bytes32(abi.encodePacked(who[0], amt[0]));
        assertTrue(drop.leafHash(7, who[0], amt[0]) != keccak256(abi.encodePacked(a, b)));
    }

    function testHiddenLeafHashBindsEveryField() public {
        bytes32 base = drop.leafHash(1, who[1], amt[1]);
        assertTrue(base != drop.leafHash(2, who[1], amt[1]));
        assertTrue(base != drop.leafHash(1, who[2], amt[1]));
        assertTrue(base != drop.leafHash(1, who[1], amt[1] + 1));
        assertEq(base, drop.leafHash(1, who[1], amt[1]));
    }

    function testHiddenEveryoneCanClaimExactlyOnce() public {
        for (uint256 i = 0; i < 4; i++) {
            drop.claim(i, who[i], amt[i], _proof(i));
            assertEq(token.balanceOf(who[i]), amt[i]);
        }
        assertEq(token.balanceOf(address(drop)), uint256(type(uint96).max) - 1000e18);
        bytes32[] memory p = _proof(3);
        vm.expectRevert(MerkleDrop.AlreadyClaimed.selector);
        drop.claim(3, who[3], amt[3], p);
        assertEq(token.balanceOf(who[3]), 610e18);
    }

    function testHiddenProofForAnotherLeafRejected() public {
        bytes32[] memory p = _proof(1);
        vm.expectRevert(MerkleDrop.InvalidProof.selector);
        drop.claim(0, who[0], amt[0], p);
        assertEq(token.balanceOf(who[0]), 0);
    }

    function testHiddenRedirectedAccountRejected() public {
        bytes32[] memory p = _proof(3);
        vm.expectRevert(MerkleDrop.InvalidProof.selector);
        drop.claim(3, address(0xBAD), amt[3], p);
        assertEq(token.balanceOf(address(0xBAD)), 0);
    }

    function testHiddenDeeperTreeNodesRejected() public {
        // Fresh drop with an 8-leaf tree; forge from a node two levels below the root.
        MerkleDrop d = new MerkleDrop(IERC20Min(address(token)));
        token.mint(address(d), type(uint96).max);
        bytes32[8] memory l;
        for (uint256 i = 0; i < 8; i++) l[i] = d.leafHash(i, address(uint160(0x9000 + i)), uint96((i + 1) * 1e18));
        bytes32 a = d.hashPair(l[0], l[1]);
        bytes32 b = d.hashPair(l[2], l[3]);
        bytes32 c = d.hashPair(l[4], l[5]);
        bytes32 e = d.hashPair(l[6], l[7]);
        bytes32 ab = d.hashPair(a, b);
        bytes32 ce = d.hashPair(c, e);
        d.setRoot(d.hashPair(ab, ce));

        // honest claim of leaf 5 works
        bytes32[] memory p = new bytes32[](3);
        p[0] = l[4];
        p[1] = e;
        p[2] = ab;
        d.claim(5, address(uint160(0x9005)), 6e18, p);
        assertEq(token.balanceOf(address(uint160(0x9005))), 6e18);

        // forged claim from node c = hashPair(l[4], l[5])
        (uint256 index, address account, uint96 amount) = _asLeaf(l[4], l[5]);
        bytes32[] memory q = new bytes32[](2);
        q[0] = e;
        q[1] = ab;
        vm.expectRevert(MerkleDrop.InvalidProof.selector);
        d.claim(index, account, amount, q);
        assertEq(token.balanceOf(account), 0);
    }

    function testHiddenRootAdministration() public {
        MerkleDrop d = new MerkleDrop(IERC20Min(address(token)));
        bytes32[] memory p = new bytes32[](0);
        vm.expectRevert(MerkleDrop.RootNotSet.selector);
        d.claim(0, who[0], amt[0], p);

        vm.expectRevert(MerkleDrop.NotOwner.selector);
        vm.prank(address(0xBAD));
        d.setRoot(bytes32(uint256(1)));
        assertEq(d.merkleRoot(), bytes32(0));

        d.setRoot(bytes32(uint256(1)));
        vm.expectRevert(MerkleDrop.RootAlreadySet.selector);
        d.setRoot(bytes32(uint256(2)));
        assertEq(d.merkleRoot(), bytes32(uint256(1)));
    }
}
