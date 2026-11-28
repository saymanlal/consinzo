// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/WrappedEther.sol";

contract WrappedEtherTest is Test {
    WrappedEther public weth;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        weth = new WrappedEther();
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function testMetadata() public view {
        assertEq(weth.name(), "Wrapped Ether");
        assertEq(weth.symbol(), "WETH");
        assertEq(uint256(weth.decimals()), 18);
    }

    function testDepositCreditsBalance() public {
        vm.prank(alice);
        weth.deposit{value: 3 ether}();
        assertEq(weth.balanceOf(alice), 3 ether);
        assertEq(weth.totalSupply(), 3 ether);
        assertEq(address(weth).balance, 3 ether);
        assertEq(alice.balance, 7 ether);
    }

    function testPlainEtherTransferDeposits() public {
        vm.prank(bob);
        (bool ok, ) = address(weth).call{value: 2 ether}("");
        assertTrue(ok);
        assertEq(weth.balanceOf(bob), 2 ether);
        assertEq(weth.totalSupply(), 2 ether);
    }

    function testWithdrawReturnsEther() public {
        vm.prank(alice);
        weth.deposit{value: 5 ether}();
        vm.prank(alice);
        weth.withdraw(2 ether);
        assertEq(weth.balanceOf(alice), 3 ether);
        assertEq(weth.totalSupply(), 3 ether);
        assertEq(alice.balance, 7 ether);
        assertEq(address(weth).balance, 3 ether);
    }

    function testTransferMovesBalance() public {
        vm.prank(alice);
        weth.deposit{value: 4 ether}();
        vm.prank(alice);
        assertTrue(weth.transfer(bob, 1 ether));
        assertEq(weth.balanceOf(alice), 3 ether);
        assertEq(weth.balanceOf(bob), 1 ether);
        assertEq(weth.totalSupply(), 4 ether);
    }
}
