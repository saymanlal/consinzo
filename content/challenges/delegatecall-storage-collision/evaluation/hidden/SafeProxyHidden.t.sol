// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/SafeProxy.sol";

contract SafeProxyHiddenTest is Test {
    function testHiddenArbitraryNumberDoesNotHijackSlot0() public {
        LogicV1 logic = new LogicV1();
        SafeProxy proxy = new SafeProxy(address(logic));
        vm.prank(address(0xBAD));
        proxy.setNumber(uint256(uint160(address(0xBAD))));
        assertEq(proxy.implementation(), address(logic));
    }
}