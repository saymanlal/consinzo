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

contract MerkleDropTest is DropFixture {
    function setUp() public {
        _deploy();
    }

    function testHonestClaim() public {
        drop.claim(1, who[1], amt[1], _proof(1));
        assertEq(token.balanceOf(who[1]), 250e18);
        assertTrue(drop.claimed(1));
    }

    function testDoubleClaimReverts() public {
        bytes32[] memory p = _proof(0);
        drop.claim(0, who[0], amt[0], p);
        vm.expectRevert(MerkleDrop.AlreadyClaimed.selector);
        drop.claim(0, who[0], amt[0], p);
        assertEq(token.balanceOf(who[0]), 100e18);
    }

    function testWrongAmountReverts() public {
        bytes32[] memory p = _proof(2);
        vm.expectRevert(MerkleDrop.InvalidProof.selector);
        drop.claim(2, who[2], amt[2] + 1, p);
        assertEq(token.balanceOf(who[2]), 0);
    }

    function testInternalNodeCannotBeClaimedAsLeaf() public {
        // Present the children of node n01 as if they were (index, account, amount).
        (uint256 index, address account, uint96 amount) = _asLeaf(leaf[0], leaf[1]);
        bytes32[] memory p = new bytes32[](1);
        p[0] = n23;

        vm.expectRevert(MerkleDrop.InvalidProof.selector);
        drop.claim(index, account, amount, p);
        assertEq(token.balanceOf(account), 0);
        assertFalse(drop.claimed(index));
        assertEq(token.balanceOf(address(drop)), type(uint96).max);
    }
}
