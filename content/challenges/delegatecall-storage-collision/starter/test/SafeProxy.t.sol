// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/SafeProxy.sol";

contract SafeProxyTest is Test {
    LogicV1 public logic;
    SafeProxy public proxy;

    function setUp() public {
        logic = new LogicV1();
        proxy = new SafeProxy(address(logic));
    }

    function testSetNumberPreservesImplementationAndOwner() public {
        address origImpl = proxy.implementation();
        address origOwner = proxy.owner();
        proxy.setNumber(12345);
        assertEq(proxy.implementation(), origImpl);
        assertEq(proxy.owner(), origOwner);
    }
}