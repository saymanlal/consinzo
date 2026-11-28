// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/EtherRouter.sol";

contract EtherRouterTest is Test {
    EtherRouter public router;
    address public alice = address(0xA11CE);

    function setUp() public {
        router = new EtherRouter();
        vm.deal(alice, 100 ether);
    }

    function testPlainTransferUsesReceive() public {
        vm.prank(alice);
        (bool ok, ) = address(router).call{value: 1 ether}("");
        assertTrue(ok, "plain transfer failed");

        assertEq(router.receiveCount(), 1);
        assertEq(router.fallbackCount(), 0);
        assertEq(router.totalViaReceive(), 1 ether);
        assertEq(router.totalViaFallback(), 0);
        assertEq(router.balance(), 1 ether);
    }

    function testUnknownSelectorUsesFallback() public {
        bytes memory data = abi.encodeWithSignature("doesNotExist(uint256)", 7);
        vm.prank(alice);
        (bool ok, ) = address(router).call{value: 2 ether}(data);
        assertTrue(ok, "unknown call failed");

        assertEq(router.fallbackCount(), 1);
        assertEq(router.receiveCount(), 0);
        assertEq(router.totalViaFallback(), 2 ether);
        assertEq(router.totalViaReceive(), 0);
        assertEq(bytes32(router.lastUnknownSelector()), bytes32(bytes4(keccak256("doesNotExist(uint256)"))));
    }

    function testContributionsAreTrackedPerSender() public {
        vm.prank(alice);
        (bool ok1, ) = address(router).call{value: 1 ether}("");
        vm.prank(alice);
        (bool ok2, ) = address(router).call{value: 3 ether}(hex"deadbeef");
        assertTrue(ok1 && ok2);

        assertEq(router.contributionOf(alice), 4 ether);
        assertEq(router.balance(), 4 ether);
    }

    function testPingIsNotAnUnknownCall() public {
        assertEq(bytes32(router.ping()), bytes32(EtherRouter.ping.selector));
        assertEq(router.receiveCount(), 0);
        assertEq(router.fallbackCount(), 0);
    }
}
