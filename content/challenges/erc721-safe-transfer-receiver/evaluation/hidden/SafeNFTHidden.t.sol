// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SafeNFT.sol";

contract HRecordingReceiver is IERC721Receiver {
    SafeNFT public nft;
    bytes4 public answer = IERC721Receiver.onERC721Received.selector;

    uint256 public calls;
    address public lastOperator;
    address public lastFrom;
    uint256 public lastTokenId;
    bytes public lastData;
    address public ownerDuringHook;
    uint256 public balanceDuringHook;
    address public approvedDuringHook;

    constructor(SafeNFT _nft) {
        nft = _nft;
    }

    function setAnswer(bytes4 a) external {
        answer = a;
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4)
    {
        calls++;
        lastOperator = operator;
        lastFrom = from;
        lastTokenId = tokenId;
        lastData = data;
        ownerDuringHook = nft.ownerOf(tokenId);
        balanceDuringHook = nft.balanceOf(address(this));
        approvedDuringHook = nft.getApproved(tokenId);
        return answer;
    }
}

contract HRevertingReceiver is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        revert("no thanks");
    }
}

contract HForwardingReceiver is IERC721Receiver {
    SafeNFT public nft;
    address public target;

    constructor(SafeNFT _nft, address _target) {
        nft = _nft;
        target = _target;
    }

    function onERC721Received(address, address, uint256 tokenId, bytes calldata) external returns (bytes4) {
        // The receiver already owns the token here and passes it on.
        nft.transferFrom(address(this), target, tokenId);
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract HPlainContract {
    uint256 public value = 1;
}

contract SafeNFTHiddenTest is Test {
    SafeNFT public nft;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA401);
    bytes4 internal constant MAGIC = 0x150b7a02;

    function setUp() public {
        nft = new SafeNFT();
        nft.safeMint(alice, 1);
        nft.safeMint(alice, 2);
    }

    function testHiddenHookArgumentsOnTransfer() public {
        HRecordingReceiver receiver = new HRecordingReceiver(nft);
        vm.prank(alice);
        nft.approve(bob, 1);

        vm.prank(bob);
        nft.safeTransferFrom(alice, address(receiver), 1, hex"c0ffee01");

        assertEq(receiver.calls(), 1);
        assertEq(receiver.lastOperator(), bob);
        assertEq(receiver.lastFrom(), alice);
        assertEq(receiver.lastTokenId(), 1);
        assertEq(keccak256(receiver.lastData()), keccak256(hex"c0ffee01"));
        assertEq(nft.ownerOf(1), address(receiver));
    }

    function testHiddenThreeArgumentOverloadSendsEmptyData() public {
        HRecordingReceiver receiver = new HRecordingReceiver(nft);
        vm.prank(alice);
        nft.safeTransferFrom(alice, address(receiver), 2);

        assertEq(receiver.calls(), 1);
        assertEq(receiver.lastOperator(), alice);
        assertEq(receiver.lastData().length, 0);
        assertEq(receiver.lastTokenId(), 2);
    }

    function testHiddenStateIsFinalInsideHook() public {
        HRecordingReceiver receiver = new HRecordingReceiver(nft);
        vm.prank(alice);
        nft.approve(bob, 1);
        vm.prank(alice);
        nft.safeTransferFrom(alice, address(receiver), 1);

        assertEq(receiver.ownerDuringHook(), address(receiver));
        assertEq(receiver.balanceDuringHook(), 1);
        assertEq(receiver.approvedDuringHook(), address(0));
    }

    function testHiddenSafeMintHookArguments() public {
        HRecordingReceiver receiver = new HRecordingReceiver(nft);
        nft.safeMint(address(receiver), 7, hex"1234");

        assertEq(receiver.calls(), 1);
        assertEq(receiver.lastOperator(), address(this));
        assertEq(receiver.lastFrom(), address(0));
        assertEq(receiver.lastTokenId(), 7);
        assertEq(keccak256(receiver.lastData()), keccak256(hex"1234"));
        assertEq(receiver.ownerDuringHook(), address(receiver));

        nft.safeMint(address(receiver), 8);
        assertEq(receiver.calls(), 2);
        assertEq(receiver.lastData().length, 0);
        assertEq(nft.balanceOf(address(receiver)), 2);
    }

    function testHiddenWrongReturnValueRejected() public {
        HRecordingReceiver receiver = new HRecordingReceiver(nft);
        receiver.setAnswer(0xdeadbeef);

        vm.prank(alice);
        vm.expectRevert(SafeNFT.UnsafeRecipient.selector);
        nft.safeTransferFrom(alice, address(receiver), 1);

        vm.prank(alice);
        vm.expectRevert(SafeNFT.UnsafeRecipient.selector);
        nft.safeTransferFrom(alice, address(receiver), 1, hex"00");

        vm.expectRevert(SafeNFT.UnsafeRecipient.selector);
        nft.safeMint(address(receiver), 9);

        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.balanceOf(alice), 2);
        assertEq(nft.balanceOf(address(receiver)), 0);
        vm.expectRevert(SafeNFT.NonexistentToken.selector);
        nft.ownerOf(9);

        // Zero is not the magic value either.
        receiver.setAnswer(bytes4(0));
        vm.prank(alice);
        vm.expectRevert(SafeNFT.UnsafeRecipient.selector);
        nft.safeTransferFrom(alice, address(receiver), 1);

        receiver.setAnswer(MAGIC);
        vm.prank(alice);
        nft.safeTransferFrom(alice, address(receiver), 1);
        assertEq(nft.ownerOf(1), address(receiver));
    }

    function testHiddenRevertingReceiverRejected() public {
        HRevertingReceiver receiver = new HRevertingReceiver();

        vm.prank(alice);
        vm.expectRevert(SafeNFT.UnsafeRecipient.selector);
        nft.safeTransferFrom(alice, address(receiver), 1);

        vm.expectRevert(SafeNFT.UnsafeRecipient.selector);
        nft.safeMint(address(receiver), 5, hex"aa");

        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.balanceOf(address(receiver)), 0);
    }

    function testHiddenSafeMintToPlainContractRejected() public {
        HPlainContract target = new HPlainContract();
        vm.expectRevert(SafeNFT.UnsafeRecipient.selector);
        nft.safeMint(address(target), 5);
        vm.expectRevert(SafeNFT.NonexistentToken.selector);
        nft.ownerOf(5);
        assertEq(nft.balanceOf(address(target)), 0);
    }

    function testHiddenTransferFromSkipsReceiverCheck() public {
        HPlainContract target = new HPlainContract();
        HRecordingReceiver receiver = new HRecordingReceiver(nft);

        vm.prank(alice);
        nft.transferFrom(alice, address(target), 1);
        assertEq(nft.ownerOf(1), address(target));

        vm.prank(alice);
        nft.transferFrom(alice, address(receiver), 2);
        assertEq(nft.ownerOf(2), address(receiver));
        assertEq(receiver.calls(), 0);
    }

    function testHiddenReceiverCanForwardTokenInsideHook() public {
        HForwardingReceiver forwarder = new HForwardingReceiver(nft, carol);

        vm.prank(alice);
        nft.safeTransferFrom(alice, address(forwarder), 1);

        assertEq(nft.ownerOf(1), carol);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.balanceOf(address(forwarder)), 0);
        assertEq(nft.balanceOf(carol), 1);

        nft.safeMint(address(forwarder), 30);
        assertEq(nft.ownerOf(30), carol);
        assertEq(nft.balanceOf(carol), 2);
    }

    function testHiddenOperatorSafeTransferAndApprove() public {
        HRecordingReceiver receiver = new HRecordingReceiver(nft);
        vm.prank(alice);
        nft.setApprovalForAll(bob, true);
        assertTrue(nft.isApprovedForAll(alice, bob));

        // An operator may approve on the owner's behalf.
        vm.prank(bob);
        nft.approve(carol, 2);
        assertEq(nft.getApproved(2), carol);

        vm.prank(bob);
        nft.safeTransferFrom(alice, address(receiver), 1);
        assertEq(receiver.lastOperator(), bob);
        assertEq(receiver.lastFrom(), alice);

        vm.prank(alice);
        nft.setApprovalForAll(bob, false);
        vm.prank(bob);
        vm.expectRevert(SafeNFT.NotAuthorized.selector);
        nft.safeTransferFrom(alice, bob, 2);

        // The per-token approval set earlier is still valid.
        vm.prank(carol);
        nft.safeTransferFrom(alice, carol, 2);
        assertEq(nft.ownerOf(2), carol);
        assertEq(nft.getApproved(2), address(0));
    }

    function testHiddenSafeTransferKeepsTransferChecks() public {
        vm.prank(bob);
        vm.expectRevert(SafeNFT.NotAuthorized.selector);
        nft.safeTransferFrom(alice, bob, 1);

        vm.prank(alice);
        vm.expectRevert(SafeNFT.WrongOwner.selector);
        nft.safeTransferFrom(bob, carol, 1);

        vm.prank(alice);
        vm.expectRevert(SafeNFT.ZeroAddress.selector);
        nft.safeTransferFrom(alice, address(0), 1, "");

        vm.prank(alice);
        vm.expectRevert(SafeNFT.NonexistentToken.selector);
        nft.safeTransferFrom(alice, bob, 99);

        vm.prank(alice);
        vm.expectRevert(SafeNFT.NotMinter.selector);
        nft.safeMint(alice, 50);

        vm.expectRevert(SafeNFT.AlreadyMinted.selector);
        nft.safeMint(bob, 1);

        vm.expectRevert(SafeNFT.ZeroAddress.selector);
        nft.safeMint(address(0), 51, "");
    }
}
