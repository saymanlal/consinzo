// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/EtherRouter.sol";

contract EtherRouterHiddenTest is Test {
    EtherRouter public router;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        router = new EtherRouter();
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    function testHiddenZeroValuePlainTransferCounts() public {
        (bool ok, ) = address(router).call("");
        assertTrue(ok, "empty call failed");
        assertEq(router.receiveCount(), 1);
        assertEq(router.fallbackCount(), 0);
        assertEq(router.totalViaReceive(), 0);
        assertEq(router.balance(), 0);
    }

    function testHiddenZeroValueUnknownCallCounts() public {
        (bool ok, ) = address(router).call(hex"12345678");
        assertTrue(ok, "unknown call failed");
        assertEq(router.fallbackCount(), 1);
        assertEq(router.receiveCount(), 0);
        assertEq(router.totalViaFallback(), 0);
        assertEq(bytes32(router.lastUnknownSelector()), bytes32(bytes4(0x12345678)));
    }

    function testHiddenShortCalldataGoesToFallback() public {
        vm.prank(alice);
        (bool ok, ) = address(router).call{value: 5}(hex"ab");
        assertTrue(ok, "short call failed");
        assertEq(router.fallbackCount(), 1);
        assertEq(router.receiveCount(), 0);
        assertEq(router.totalViaFallback(), 5);
        assertEq(bytes32(router.lastUnknownSelector()), bytes32(bytes4(0xab000000)));
    }

    function testHiddenLastSelectorIsOverwritten() public {
        (bool ok1, ) = address(router).call(hex"aaaaaaaa01");
        (bool ok2, ) = address(router).call(abi.encodeWithSignature("transfer(address,uint256)", bob, 1));
        assertTrue(ok1 && ok2);
        assertEq(router.fallbackCount(), 2);
        assertEq(bytes32(router.lastUnknownSelector()), bytes32(bytes4(0xa9059cbb)));

        // A plain transfer leaves the recorded selector alone.
        (bool ok3, ) = address(router).call{value: 1}("");
        assertTrue(ok3);
        assertEq(bytes32(router.lastUnknownSelector()), bytes32(bytes4(0xa9059cbb)));
    }

    function testHiddenMixedSequenceKeepsSeparateTotals() public {
        vm.prank(alice);
        (bool a, ) = address(router).call{value: 1 ether}("");
        vm.prank(bob);
        (bool b, ) = address(router).call{value: 2 ether}(hex"01020304");
        vm.prank(bob);
        (bool c, ) = address(router).call{value: 4 ether}("");
        vm.prank(alice);
        (bool d, ) = address(router).call{value: 8 ether}(hex"0102030405060708");
        vm.prank(alice);
        (bool e, ) = address(router).call{value: 16 ether}("");
        assertTrue(a && b && c && d && e);

        assertEq(router.receiveCount(), 3);
        assertEq(router.fallbackCount(), 2);
        assertEq(router.totalViaReceive(), 21 ether);
        assertEq(router.totalViaFallback(), 10 ether);
        assertEq(router.contributionOf(alice), 25 ether);
        assertEq(router.contributionOf(bob), 6 ether);
        assertEq(router.balance(), 31 ether);
        assertEq(alice.balance, 75 ether);
    }

    function testHiddenDeclaredFunctionsDoNotCount() public {
        vm.prank(alice);
        (bool ok, ) = address(router).call{value: 1 ether}("");
        assertTrue(ok);

        router.ping();
        router.balance();
        router.receiveCount();
        router.contributionOf(alice);
        (bool pinged, bytes memory ret) = address(router).call(abi.encodeWithSignature("ping()"));
        assertTrue(pinged);
        assertEq(abi.decode(ret, (bytes32)), bytes32(EtherRouter.ping.selector));

        assertEq(router.receiveCount(), 1);
        assertEq(router.fallbackCount(), 0);
        assertEq(bytes32(router.lastUnknownSelector()), bytes32(0));
    }

    function testHiddenValueSentToNonPayableFunctionIsRejected() public {
        // ping() is not payable, so value must not slip in through a declared function.
        vm.prank(alice);
        (bool ok, ) = address(router).call{value: 1 ether}(abi.encodeWithSignature("ping()"));
        assertFalse(ok, "non-payable function accepted value");
        assertEq(router.balance(), 0);
        assertEq(router.contributionOf(alice), 0);
        assertEq(router.receiveCount() + router.fallbackCount(), 0);
    }
}
