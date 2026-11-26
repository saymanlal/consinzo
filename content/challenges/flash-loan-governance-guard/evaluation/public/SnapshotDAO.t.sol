// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/SnapshotDAO.sol";

contract MockGovToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function mint(address to, uint256 a) external { balanceOf[to] += a; }
    function approve(address s, uint256 a) external returns (bool) { allowance[msg.sender][s] = a; return true; }
    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        allowance[f][msg.sender] -= a; balanceOf[f] -= a; balanceOf[t] += a; return true;
    }
}

contract SnapshotDAOTest is Test {
    MockGovToken public gov;
    SnapshotDAO public dao;
    address public alice = address(0xA11CE);
    address public flashAttacker = address(0xBAD);

    function setUp() public {
        gov = new MockGovToken();
        dao = new SnapshotDAO(address(gov));
        gov.mint(alice, 100);
        vm.prank(alice); gov.approve(address(dao), 100);
        vm.prank(alice); dao.lockVotes(100);
    }

    function testPreLockedVoterSucceedsAfterProposal() public {
        vm.roll(block.number + 1);
        uint256 id = dao.createProposal();
        vm.prank(alice);
        dao.vote(id);
        assertEq(dao.yesVotes(id), 100);
    }

    function testSameBlockFlashLockBlocked() public {
        uint256 id = dao.createProposal();
        gov.mint(flashAttacker, 1_000_000);
        vm.prank(flashAttacker); gov.approve(address(dao), 1_000_000);
        vm.prank(flashAttacker); dao.lockVotes(1_000_000);
        vm.prank(flashAttacker);
        vm.expectRevert();
        dao.vote(id);
    }
}