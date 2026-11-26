// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/OracleLending.sol";

contract MockOracle {
    uint256 public spotPrice = 2000e18;
    uint256 public twapPrice = 2000e18;
    function setSpot(uint256 p) external { spotPrice = p; }
}

contract OracleLendingTest is Test {
    MockOracle public oracle;
    OracleLending public lending;
    address public alice = address(0xA11CE);

    function setUp() public {
        oracle = new MockOracle();
        lending = new OracleLending(address(oracle));
        vm.deal(alice, 5 ether);
        vm.prank(alice);
        lending.depositCollateral{value: 1 ether}();
    }

    function testNormalBorrowWorks() public {
        vm.prank(alice);
        lending.borrow(900e18);
        assertEq(lending.debtUsd(alice), 900e18);
    }

    function testSpotManipulationSpikeBlocked() public {
        oracle.setSpot(10000e18);
        vm.prank(alice);
        vm.expectRevert();
        lending.borrow(4000e18);
    }
}