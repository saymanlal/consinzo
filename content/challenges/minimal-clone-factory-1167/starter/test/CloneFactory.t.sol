// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/CloneFactory.sol";

contract CounterImpl {
    uint256 public count;
    function inc() external { count += 1; }
}

contract CloneFactoryTest is Test {
    function testMinimalProxyClonesHaveIsolatedStorage() public {
        CounterImpl impl = new CounterImpl();
        CloneFactory factory = new CloneFactory();
        CounterImpl c1 = CounterImpl(factory.clone(address(impl)));
        CounterImpl c2 = CounterImpl(factory.clone(address(impl)));
        c1.inc();
        c1.inc();
        c2.inc();
        assertEq(c1.count(), 2);
        assertEq(c2.count(), 1);
        assertEq(impl.count(), 0);
    }
}