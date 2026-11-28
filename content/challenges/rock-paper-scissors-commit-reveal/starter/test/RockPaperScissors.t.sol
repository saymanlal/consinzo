// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RockPaperScissors.sol";

contract RockPaperScissorsTest is Test {
    RockPaperScissors public game;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    uint256 constant STAKE = 1 ether;
    uint256 constant REVEAL_PERIOD = 1 hours;
    bytes32 constant SALT_A = keccak256("alice salt");
    bytes32 constant SALT_B = keccak256("bob salt");

    function setUp() public {
        game = new RockPaperScissors(STAKE, REVEAL_PERIOD);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function _join(address who, RockPaperScissors.Move move, bytes32 salt) internal {
        bytes32 c = game.commitmentOf(who, move, salt);
        vm.prank(who);
        game.join{value: STAKE}(c);
    }

    function testJoinStartsRevealPhase() public {
        _join(alice, RockPaperScissors.Move.Rock, SALT_A);
        assertEq(uint256(game.phase()), uint256(RockPaperScissors.Phase.Waiting));
        assertEq(game.player1(), alice);

        _join(bob, RockPaperScissors.Move.Paper, SALT_B);
        assertEq(uint256(game.phase()), uint256(RockPaperScissors.Phase.Reveal));
        assertEq(game.player2(), bob);
        assertEq(game.revealDeadline(), block.timestamp + REVEAL_PERIOD);
        assertEq(address(game).balance, 2 ether);
    }

    function testPaperBeatsRock() public {
        _join(alice, RockPaperScissors.Move.Rock, SALT_A);
        _join(bob, RockPaperScissors.Move.Paper, SALT_B);

        vm.prank(alice);
        game.reveal(RockPaperScissors.Move.Rock, SALT_A);
        vm.prank(bob);
        game.reveal(RockPaperScissors.Move.Paper, SALT_B);
        game.settle();

        assertEq(uint256(game.phase()), uint256(RockPaperScissors.Phase.Finished));
        assertEq(game.winner(), bob);
        assertEq(game.winnings(bob), 2 ether);
        assertEq(game.winnings(alice), 0);

        vm.prank(bob);
        game.withdraw();
        assertEq(bob.balance, 11 ether);
    }

    function testDrawSplitsPot() public {
        _join(alice, RockPaperScissors.Move.Scissors, SALT_A);
        _join(bob, RockPaperScissors.Move.Scissors, SALT_B);
        vm.prank(alice);
        game.reveal(RockPaperScissors.Move.Scissors, SALT_A);
        vm.prank(bob);
        game.reveal(RockPaperScissors.Move.Scissors, SALT_B);
        game.settle();

        assertEq(game.winner(), address(0));
        assertEq(game.winnings(alice), 1 ether);
        assertEq(game.winnings(bob), 1 ether);
    }

    function testNonRevealerForfeits() public {
        _join(alice, RockPaperScissors.Move.Rock, SALT_A);
        _join(bob, RockPaperScissors.Move.Paper, SALT_B);

        // Alice reveals; Bob, who would have won, stays silent.
        vm.prank(alice);
        game.reveal(RockPaperScissors.Move.Rock, SALT_A);

        vm.expectRevert(RockPaperScissors.RevealPending.selector);
        game.settle();

        vm.warp(block.timestamp + REVEAL_PERIOD);
        game.settle();
        assertEq(game.winner(), alice);
        assertEq(game.winnings(alice), 2 ether);
    }

    function testWrongSaltReverts() public {
        _join(alice, RockPaperScissors.Move.Rock, SALT_A);
        _join(bob, RockPaperScissors.Move.Paper, SALT_B);

        vm.prank(alice);
        vm.expectRevert(RockPaperScissors.CommitmentMismatch.selector);
        game.reveal(RockPaperScissors.Move.Rock, SALT_B);
    }
}
