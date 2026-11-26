// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/OracleLending.sol";

contract MockOracleH {
    uint256 public spotPrice = 2000e18;
    uint256 public twapPrice = 2000e18;
    function setSpot(uint256 p) external { spotPrice = p; }
}

contract OracleLendingHiddenTest is Test {
    function testHiddenDownwardSpotManipulationRejected() public {
        MockOracleH o = new MockOracleH();
        OracleLending l = new OracleLending(address(o));
        vm.deal(address(0xA11CE), 2 ether);
        vm.prank(address(0xA11CE));
        l.depositCollateral{value: 1 ether}();
        o.setSpot(500e18);
        vm.prank(address(0xA11CE));
        vm.expectRevert();
        l.borrow(100e18);
    }
}