// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MetaTxRecipient.sol";

contract HiddenForwarder {
    function forward(address target, address from, bytes calldata data) external payable returns (bytes memory) {
        return _call(target, abi.encodePacked(data, from), msg.value);
    }

    /// Sends `data` unchanged, without appending anything.
    function forwardRaw(address target, bytes calldata data) external payable returns (bytes memory) {
        return _call(target, data, msg.value);
    }

    function _call(address target, bytes memory data, uint256 value) private returns (bytes memory) {
        (bool ok, bytes memory ret) = target.call{value: value}(data);
        if (!ok) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
        return ret;
    }

    receive() external payable {}
}

contract MetaTxRecipientHiddenTest is Test {
    MetaTxRecipient public recipient;
    HiddenForwarder public forwarder;
    HiddenForwarder public rogue;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        forwarder = new HiddenForwarder();
        rogue = new HiddenForwarder();
        recipient = new MetaTxRecipient(address(forwarder));
    }

    function testHiddenWithdrawPaysEffectiveSenderNotForwarder() public {
        forwarder.forward{value: 3 ether}(address(recipient), alice, abi.encodeCall(MetaTxRecipient.deposit, ()));
        uint256 forwarderBefore = address(forwarder).balance;

        forwarder.forward(address(recipient), alice, abi.encodeCall(MetaTxRecipient.withdraw, (1 ether)));

        assertEq(alice.balance, 1 ether);
        assertEq(address(forwarder).balance, forwarderBefore);
        assertEq(recipient.balanceOf(alice), 2 ether);
        assertEq(address(recipient).balance, 2 ether);
    }

    function testHiddenForwardedWithdrawCannotExceedOwnBalance() public {
        vm.deal(bob, 5 ether);
        vm.prank(bob);
        recipient.deposit{value: 5 ether}();

        forwarder.forward{value: 1 ether}(address(recipient), alice, abi.encodeCall(MetaTxRecipient.deposit, ()));
        vm.expectRevert(MetaTxRecipient.InsufficientBalance.selector);
        forwarder.forward(address(recipient), alice, abi.encodeCall(MetaTxRecipient.withdraw, (2 ether)));

        assertEq(recipient.balanceOf(bob), 5 ether);
        assertEq(recipient.balanceOf(alice), 1 ether);
    }

    function testHiddenRogueForwarderIsNotTrusted() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        recipient.deposit{value: 1 ether}();

        // A different forwarder contract appends Alice's address: it acts only as itself.
        vm.expectRevert(MetaTxRecipient.InsufficientBalance.selector);
        rogue.forward(address(recipient), alice, abi.encodeCall(MetaTxRecipient.withdraw, (1 ether)));

        rogue.forward(address(recipient), alice, abi.encodeCall(MetaTxRecipient.setNote, ("rogue")));
        assertEq(recipient.noteOf(alice), "");
        assertEq(recipient.noteOf(address(rogue)), "rogue");
        assertEq(recipient.balanceOf(alice), 1 ether);
    }

    function testHiddenOwnershipThroughForwarder() public {
        // The test contract is the owner. The forwarder relays on its behalf.
        forwarder.forward(
            address(recipient), address(this), abi.encodeCall(MetaTxRecipient.transferOwnership, (alice))
        );
        assertEq(recipient.owner(), alice);

        // Relayed for Bob, who is not the owner.
        vm.expectRevert(MetaTxRecipient.NotOwner.selector);
        forwarder.forward(address(recipient), bob, abi.encodeCall(MetaTxRecipient.transferOwnership, (bob)));

        // The old owner calling directly is rejected as well.
        vm.expectRevert(MetaTxRecipient.NotOwner.selector);
        recipient.transferOwnership(bob);

        vm.prank(alice);
        vm.expectRevert(MetaTxRecipient.ZeroAddress.selector);
        recipient.transferOwnership(address(0));
        assertEq(recipient.owner(), alice);
    }

    function testHiddenSpoofedOwnerSuffixFromUntrustedCaller() public {
        // Bob appends the owner's address to a direct call.
        vm.prank(bob);
        (bool ok,) = address(recipient).call(
            abi.encodePacked(abi.encodeCall(MetaTxRecipient.transferOwnership, (bob)), address(this))
        );
        assertFalse(ok);
        assertEq(recipient.owner(), address(this));
    }

    function testHiddenShortCalldataFromForwarderFallsBackToMsgSender() public {
        // Only the 4-byte selector, nothing appended: fewer than 20 bytes of calldata.
        bytes memory ret = forwarder.forwardRaw(address(recipient), abi.encodeCall(MetaTxRecipient.context, ()));
        (address sender, bytes memory data) = abi.decode(ret, (address, bytes));
        assertEq(sender, address(forwarder));
        assertEq(data.length, 4);
        assertEq(keccak256(data), keccak256(abi.encodeCall(MetaTxRecipient.context, ())));
    }

    function testHiddenUntrustedContextKeepsFullCalldata() public {
        bytes memory payload = abi.encodePacked(abi.encodeCall(MetaTxRecipient.context, ()), alice);
        vm.prank(bob);
        (bool ok, bytes memory ret) = address(recipient).call(payload);
        assertTrue(ok);
        (address sender, bytes memory data) = abi.decode(ret, (address, bytes));
        assertEq(sender, bob);
        assertEq(data.length, 24);
        assertEq(keccak256(data), keccak256(payload));
    }

    function testHiddenForwardedDataWithArgumentsIsStrippedExactly() public {
        // setNote arguments must decode correctly with the suffix present, and two users
        // relayed through the same forwarder stay separate.
        forwarder.forward(address(recipient), alice, abi.encodeCall(MetaTxRecipient.setNote, ("a long note for alice, well over thirty-two bytes")));
        forwarder.forward(address(recipient), bob, abi.encodeCall(MetaTxRecipient.setNote, ("bob")));
        assertEq(recipient.noteOf(alice), "a long note for alice, well over thirty-two bytes");
        assertEq(recipient.noteOf(bob), "bob");
    }

    function testHiddenConstructorRejectsZeroForwarder() public {
        try new MetaTxRecipient(address(0)) {
            assertTrue(false, "zero forwarder accepted");
        } catch (bytes memory err) {
            assertEq(bytes4(err), MetaTxRecipient.ZeroAddress.selector);
        }
    }
}
