// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RevenueSplitter.sol";

contract RejectingPayee {
    bool public accept;

    function setAccept(bool value) external {
        accept = value;
    }

    receive() external payable {
        require(accept, "no eth");
    }
}

contract ReentrantPayee {
    RevenueSplitter public splitter;
    uint256 public attempts;

    function setSplitter(RevenueSplitter s) external {
        splitter = s;
    }

    receive() external payable {
        if (attempts < 3) {
            attempts++;
            // Try to be paid again while the first payment is in flight.
            try splitter.release(address(this)) {} catch {}
        }
    }
}

contract RevenueSplitterHiddenTest is Test {
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA201);

    function deploy(address[] memory p, uint256[] memory s) external returns (RevenueSplitter) {
        return new RevenueSplitter(p, s);
    }

    function _three(uint256 a, uint256 b, uint256 c) internal returns (RevenueSplitter) {
        address[] memory p = new address[](3);
        uint256[] memory s = new uint256[](3);
        (p[0], p[1], p[2]) = (alice, bob, carol);
        (s[0], s[1], s[2]) = (a, b, c);
        return new RevenueSplitter(p, s);
    }

    function _pay(RevenueSplitter splitter, uint256 amount) internal {
        (bool ok, ) = address(splitter).call{value: amount}("");
        assertTrue(ok, "payment failed");
    }

    function testHiddenConstructorValidation() public {
        address[] memory p = new address[](2);
        uint256[] memory s = new uint256[](2);
        (p[0], p[1]) = (alice, bob);
        (s[0], s[1]) = (1, 1);

        vm.expectRevert(RevenueSplitter.InvalidPayees.selector);
        this.deploy(new address[](0), new uint256[](0));
        vm.expectRevert(RevenueSplitter.InvalidPayees.selector);
        this.deploy(p, new uint256[](3));

        p[1] = address(0);
        vm.expectRevert(RevenueSplitter.ZeroAddress.selector);
        this.deploy(p, s);

        p[1] = bob;
        s[1] = 0;
        vm.expectRevert(RevenueSplitter.ZeroShares.selector);
        this.deploy(p, s);

        s[1] = 1;
        p[1] = alice;
        vm.expectRevert(RevenueSplitter.DuplicatePayee.selector);
        this.deploy(p, s);
    }

    function testHiddenRoundingDustStaysInContract() public {
        RevenueSplitter splitter = _three(1, 1, 1);
        _pay(splitter, 100);
        assertEq(splitter.releasable(alice), 33);
        splitter.release(alice);
        splitter.release(bob);
        splitter.release(carol);
        assertEq(address(splitter).balance, 1);
        assertEq(splitter.totalReleased(), 99);
        vm.expectRevert(RevenueSplitter.NothingDue.selector);
        splitter.release(alice);
        // 2 more wei make the total 102, i.e. 34 each
        _pay(splitter, 2);
        assertEq(splitter.releasable(alice), 1);
        assertEq(splitter.release(bob), 1);
        assertEq(bob.balance, 34);
    }

    function testHiddenOrderOfReleasesDoesNotMatter() public {
        RevenueSplitter splitter = _three(7, 2, 1);
        _pay(splitter, 3 ether);
        splitter.release(carol);
        _pay(splitter, 5 ether);
        splitter.release(alice);
        _pay(splitter, 2 ether);
        splitter.release(carol);
        splitter.release(bob);
        splitter.release(alice);
        assertEq(alice.balance, 7 ether);
        assertEq(bob.balance, 2 ether);
        assertEq(carol.balance, 1 ether);
        assertEq(address(splitter).balance, 0);
        assertEq(splitter.totalReceived(), 10 ether);
    }

    function testHiddenNothingDueAndNonPayee() public {
        RevenueSplitter splitter = _three(1, 1, 2);
        vm.expectRevert(RevenueSplitter.NothingDue.selector);
        splitter.release(alice);
        assertEq(splitter.releasable(address(0xDEAD)), 0);
        vm.expectRevert(RevenueSplitter.NotPayee.selector);
        splitter.release(address(0xDEAD));
    }

    function testHiddenFailingPayeeBlocksOnlyItself() public {
        RejectingPayee bad = new RejectingPayee();
        address[] memory p = new address[](2);
        uint256[] memory s = new uint256[](2);
        (p[0], p[1]) = (address(bad), alice);
        (s[0], s[1]) = (1, 3);
        RevenueSplitter splitter = new RevenueSplitter(p, s);
        _pay(splitter, 4 ether);

        vm.expectRevert(RevenueSplitter.TransferFailed.selector);
        splitter.release(address(bad));
        // the failed release left no trace
        assertEq(splitter.released(address(bad)), 0);
        assertEq(splitter.totalReleased(), 0);

        splitter.release(alice);
        assertEq(alice.balance, 3 ether);

        bad.setAccept(true);
        assertEq(splitter.release(address(bad)), 1 ether);
        assertEq(address(bad).balance, 1 ether);
    }

    function testHiddenReentrantPayeeGetsOnlyItsShare() public {
        ReentrantPayee attacker = new ReentrantPayee();
        address[] memory p = new address[](2);
        uint256[] memory s = new uint256[](2);
        (p[0], p[1]) = (address(attacker), alice);
        (s[0], s[1]) = (1, 1);
        RevenueSplitter splitter = new RevenueSplitter(p, s);
        attacker.setSplitter(splitter);
        _pay(splitter, 2 ether);

        splitter.release(address(attacker));
        assertEq(address(attacker).balance, 1 ether);
        assertEq(splitter.releasable(alice), 1 ether);
        splitter.release(alice);
        assertEq(alice.balance, 1 ether);
    }

    function testHiddenConstructorValueCountsAsRevenue() public {
        address[] memory p = new address[](2);
        uint256[] memory s = new uint256[](2);
        (p[0], p[1]) = (alice, bob);
        (s[0], s[1]) = (3, 1);
        RevenueSplitter splitter = new RevenueSplitter{value: 4 ether}(p, s);
        assertEq(splitter.totalReceived(), 4 ether);
        assertEq(splitter.releasable(alice), 3 ether);
        assertEq(splitter.releasable(bob), 1 ether);
    }
}
