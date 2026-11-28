// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/WrappedEther.sol";

contract EtherRejecter {
    WrappedEther public weth;

    constructor(WrappedEther _weth) {
        weth = _weth;
    }

    function depositAndWithdraw() external payable {
        weth.deposit{value: msg.value}();
        weth.withdraw(msg.value);
    }
    // No receive or fallback: Ether sent here is rejected.
}

contract ReenteringWithdrawer {
    WrappedEther public weth;
    uint256 public reentryAttempts;
    uint256 public reentrySuccesses;

    constructor(WrappedEther _weth) {
        weth = _weth;
    }

    function attack() external payable {
        weth.deposit{value: msg.value}();
        weth.withdraw(msg.value);
    }

    receive() external payable {
        if (reentryAttempts < 3) {
            reentryAttempts++;
            try weth.withdraw(msg.value) {
                reentrySuccesses++;
            } catch {}
        }
    }
}

contract WrappedEtherHiddenTest is Test {
    WrappedEther public weth;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        weth = new WrappedEther();
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function testHiddenWithdrawMoreThanBalanceReverts() public {
        vm.prank(alice);
        weth.deposit{value: 1 ether}();
        vm.prank(bob);
        weth.deposit{value: 5 ether}();

        vm.prank(alice);
        vm.expectRevert(WrappedEther.InsufficientBalance.selector);
        weth.withdraw(1 ether + 1);

        assertEq(weth.balanceOf(alice), 1 ether);
        assertEq(address(weth).balance, 6 ether);
    }

    function testHiddenTransferRevertPaths() public {
        vm.prank(alice);
        weth.deposit{value: 1 ether}();

        vm.prank(alice);
        vm.expectRevert(WrappedEther.ZeroAddress.selector);
        weth.transfer(address(0), 1);

        vm.prank(alice);
        vm.expectRevert(WrappedEther.InsufficientBalance.selector);
        weth.transfer(bob, 1 ether + 1);

        assertEq(weth.balanceOf(alice), 1 ether);
        assertEq(weth.balanceOf(bob), 0);
    }

    function testHiddenTransferThenRecipientWithdraws() public {
        vm.prank(alice);
        weth.deposit{value: 4 ether}();
        vm.prank(alice);
        weth.transfer(bob, 4 ether);

        vm.prank(bob);
        weth.withdraw(4 ether);
        assertEq(bob.balance, 14 ether);
        assertEq(weth.balanceOf(bob), 0);
        assertEq(weth.totalSupply(), 0);
        assertEq(address(weth).balance, 0);

        vm.prank(alice);
        vm.expectRevert(WrappedEther.InsufficientBalance.selector);
        weth.withdraw(1);
    }

    function testHiddenZeroValueOperationsAllowed() public {
        vm.prank(alice);
        weth.deposit{value: 0}();
        vm.prank(alice);
        weth.withdraw(0);
        vm.prank(alice);
        assertTrue(weth.transfer(bob, 0));
        assertEq(weth.totalSupply(), 0);
    }

    function testHiddenRejectedEtherRevertsWithdraw() public {
        vm.prank(bob);
        weth.deposit{value: 2 ether}();

        EtherRejecter rejecter = new EtherRejecter(weth);
        vm.expectRevert(WrappedEther.EthTransferFailed.selector);
        rejecter.depositAndWithdraw{value: 1 ether}();

        assertEq(weth.balanceOf(address(rejecter)), 0);
        assertEq(weth.totalSupply(), 2 ether);
        assertEq(address(weth).balance, 2 ether);
    }

    function testHiddenReentrantWithdrawCannotDrain() public {
        vm.prank(bob);
        weth.deposit{value: 5 ether}();

        ReenteringWithdrawer attacker = new ReenteringWithdrawer(weth);
        attacker.attack{value: 1 ether}();

        assertGt(attacker.reentryAttempts(), 0);
        assertEq(attacker.reentrySuccesses(), 0);
        assertEq(address(attacker).balance, 1 ether);
        assertEq(weth.balanceOf(address(attacker)), 0);
        assertEq(weth.balanceOf(bob), 5 ether);
        assertEq(weth.totalSupply(), 5 ether);
        assertEq(address(weth).balance, 5 ether);
    }

    function testHiddenSupplyTracksEtherAcrossSequence() public {
        vm.prank(alice);
        weth.deposit{value: 3 ether}();
        vm.prank(bob);
        (bool ok, ) = address(weth).call{value: 2 ether}("");
        assertTrue(ok);
        vm.prank(alice);
        weth.transfer(bob, 1 ether);
        vm.prank(bob);
        weth.withdraw(2.5 ether);

        assertEq(weth.balanceOf(alice), 2 ether);
        assertEq(weth.balanceOf(bob), 0.5 ether);
        assertEq(weth.totalSupply(), 2.5 ether);
        assertEq(address(weth).balance, weth.totalSupply());
    }
}
