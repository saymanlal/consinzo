// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MetaTxRecipient.sol";

/// Minimal forwarder for tests: appends `from` to the calldata as EIP-2771 prescribes.
/// A production forwarder would verify a signature of `from` first.
contract SimpleForwarder {
    function forward(address target, address from, bytes calldata data) external payable returns (bytes memory) {
        (bool ok, bytes memory ret) = target.call{value: msg.value}(abi.encodePacked(data, from));
        if (!ok) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
        return ret;
    }
}

contract MetaTxRecipientTest is Test {
    MetaTxRecipient public recipient;
    SimpleForwarder public forwarder;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        forwarder = new SimpleForwarder();
        recipient = new MetaTxRecipient(address(forwarder));
    }

    function testSetup() public view {
        assertEq(recipient.trustedForwarder(), address(forwarder));
        assertTrue(recipient.isTrustedForwarder(address(forwarder)));
        assertFalse(recipient.isTrustedForwarder(alice));
        assertEq(recipient.owner(), address(this));
    }

    function testDirectCallUsesMsgSender() public {
        vm.prank(alice);
        recipient.setNote("direct");
        assertEq(recipient.noteOf(alice), "direct");

        vm.prank(alice);
        (address sender, bytes memory data) = recipient.context();
        assertEq(sender, alice);
        assertEq(keccak256(data), keccak256(abi.encodeCall(MetaTxRecipient.context, ())));
    }

    function testForwardedCallUsesAppendedSender() public {
        forwarder.forward(address(recipient), alice, abi.encodeCall(MetaTxRecipient.setNote, ("relayed")));
        assertEq(recipient.noteOf(alice), "relayed");
        assertEq(recipient.noteOf(address(forwarder)), "");
    }

    function testForwardedContextStripsSuffix() public {
        bytes memory ret =
            forwarder.forward(address(recipient), bob, abi.encodeCall(MetaTxRecipient.context, ()));
        (address sender, bytes memory data) = abi.decode(ret, (address, bytes));
        assertEq(sender, bob);
        assertEq(keccak256(data), keccak256(abi.encodeCall(MetaTxRecipient.context, ())));
    }

    function testUntrustedCallerCannotSpoof() public {
        // Bob appends Alice's address himself. He is not the forwarder, so it is ignored.
        vm.prank(bob);
        (bool ok,) =
            address(recipient).call(abi.encodePacked(abi.encodeCall(MetaTxRecipient.setNote, ("spoof")), alice));
        assertTrue(ok);
        assertEq(recipient.noteOf(alice), "");
        assertEq(recipient.noteOf(bob), "spoof");
    }

    function testForwardedDepositCreditsUser() public {
        forwarder.forward{value: 2 ether}(address(recipient), alice, abi.encodeCall(MetaTxRecipient.deposit, ()));
        assertEq(recipient.balanceOf(alice), 2 ether);
        assertEq(recipient.balanceOf(address(forwarder)), 0);
    }
}
