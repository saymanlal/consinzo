// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/VoucherRedeemer.sol";

contract VoucherRedeemerTest is Test {
    // Vouchers below were signed off-chain by SIGNER for this exact deployment:
    // chain id 1 and the redeemer address produced by deploying it first in setUp().
    address internal constant SIGNER = 0x3971292981aAB0456BBBc199D527298355CBB514;
    address internal constant REDEEMER_ADDR = 0x97B0aBF484ECbcc9c901f4CfD91C5842d7DDb623;

    // voucher A: alice, 1 ether, nonce 1
    bytes32 internal constant A_R = 0x712e028b9fcef594b42f915d6f61279e9d65bc4fdb1f5b5b2cc7aaa4064742b5;
    bytes32 internal constant A_S = 0x21ec567b73ac0aacf68c50903f6d9a340bf28cb24b0d6c3732ab3456c38892f7;
    // voucher B: alice, 2 ether, nonce 2
    bytes32 internal constant B_R = 0x5d608db584236c311f61f836008b8398f0007113f796d48757ff3d6b37817e80;
    bytes32 internal constant B_S = 0x148f0dd184a97609a6b3fba6069cf13f6ec44197fc29d0066aaaf843ef4ec023;
    // voucher C: bob, 3 ether, nonce 7
    bytes32 internal constant C_R = 0xc8cacc7b54e5d6cb5f84f0acd806d295898f2bdbf792bba6b88288546fc512fc;
    bytes32 internal constant C_S = 0x2c7189403bde4934a092f2ef171b9ea0457e5ea34de833c87dfcfe02c38eeec3;
    uint8 internal constant V = 27;

    VoucherRedeemer public redeemer;
    address public alice = address(0xA11CE);
    address public attacker = address(0xBAD);

    function setUp() public {
        redeemer = new VoucherRedeemer{value: 10 ether}();
        assertEq(address(redeemer), REDEEMER_ADDR, "fixture address changed");
    }

    function testValidVoucherRedeems() public {
        redeemer.setSigner(SIGNER);
        vm.prank(alice);
        redeemer.redeem(1 ether, 1, V, A_R, A_S);
        assertEq(alice.balance, 1 ether);
        assertTrue(redeemer.usedNonce(1));
        assertEq(address(redeemer).balance, 9 ether);
    }

    function testVoucherCannotBeReplayed() public {
        redeemer.setSigner(SIGNER);
        vm.prank(alice);
        redeemer.redeem(1 ether, 1, V, A_R, A_S);
        vm.expectRevert(VoucherRedeemer.VoucherUsed.selector);
        vm.prank(alice);
        redeemer.redeem(1 ether, 1, V, A_R, A_S);
        assertEq(alice.balance, 1 ether);
    }

    function testGarbageSignatureRejectedBeforeSignerIsSet() public {
        // v = 0 is not a valid recovery id, so ecrecover yields address(0).
        vm.expectRevert();
        vm.prank(attacker);
        redeemer.redeem(10 ether, 1, 0, bytes32(0), bytes32(0));
        assertEq(attacker.balance, 0);
        assertEq(address(redeemer).balance, 10 ether);
    }

    function testGarbageSignatureRejectedWhilePaused() public {
        redeemer.setSigner(SIGNER);
        redeemer.clearSigner();
        vm.expectRevert();
        vm.prank(attacker);
        redeemer.redeem(10 ether, 99, 0, bytes32(0), bytes32(0));
        assertEq(attacker.balance, 0);
        assertEq(address(redeemer).balance, 10 ether);
    }
}
