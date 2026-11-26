// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/SnapshotDAO.sol";

contract MockGovH {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function mint(address to, uint256 a) external { balanceOf[to] += a; }
    function approve(address s, uint256 a) external returns (bool) { allowance[msg.sender][s] = a; return true; }
    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        allowance[f][msg.sender] -= a; balanceOf[f] -= a; balanceOf[t] += a; return true;
    }
}

contract SnapshotDAOHiddenTest is Test {
    function testHiddenCannotDoubleVote() public {
        MockGovH g = new MockGovH();
        SnapshotDAO d = new SnapshotDAO(address(g));
        address u = address(0x111);
        g.mint(u, 50);
        vm.prank(u); g.approve(address(d), 50);
        vm.prank(u); d.lockVotes(50);
        vm.roll(block.number + 1);
        uint256 id = d.createProposal();
        vm.prank(u); d.vote(id);
        vm.prank(u);
        vm.expectRevert();
        d.vote(id);
    }
}