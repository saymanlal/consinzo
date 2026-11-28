// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RockPaperScissors.sol";

contract RockPaperScissorsHiddenTest is Test {
    RockPaperScissors public game;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA401);

    uint256 constant STAKE = 1 ether;
    uint256 constant REVEAL_PERIOD = 1 hours;
    bytes32 constant SALT_A = keccak256("a");
    bytes32 constant SALT_B = keccak256("b");

    function setUp() public {
        game = new RockPaperScissors(STAKE, REVEAL_PERIOD);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(carol, 10 ether);
    }

    function _commit(address who, uint8 move, bytes32 salt) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(who, move, salt));
    }

    function _play(RockPaperScissors g, uint8 a, uint8 b) internal returns (address) {
        vm.prank(alice);
        g.join{value: STAKE}(_commit(alice, a, SALT_A));
        vm.prank(bob);
        g.join{value: STAKE}(_commit(bob, b, SALT_B));
        vm.prank(alice);
        g.reveal(RockPaperScissors.Move(a), SALT_A);
        vm.prank(bob);
        g.reveal(RockPaperScissors.Move(b), SALT_B);
        g.settle();
        return g.winner();
    }

    function testHiddenAllNineOutcomes() public {
        // expected[a-1][b-1]: 0 draw, 1 alice, 2 bob
        uint8[3][3] memory expected = [[0, 2, 1], [1, 0, 2], [2, 1, 0]];
        for (uint8 a = 1; a <= 3; a++) {
            for (uint8 b = 1; b <= 3; b++) {
                RockPaperScissors g = new RockPaperScissors(STAKE, REVEAL_PERIOD);
                address w = _play(g, a, b);
                uint8 e = expected[a - 1][b - 1];
                if (e == 0) {
                    assertEq(w, address(0));
                    assertEq(g.winnings(alice), STAKE);
                    assertEq(g.winnings(bob), STAKE);
                } else {
                    address expectedWinner = e == 1 ? alice : bob;
                    address loser = e == 1 ? bob : alice;
                    assertEq(w, expectedWinner);
                    assertEq(g.winnings(expectedWinner), 2 * STAKE);
                    assertEq(g.winnings(loser), 0);
                }
            }
        }
    }

    function testHiddenCommitmentFormat() public view {
        assertEq(
            game.commitmentOf(alice, RockPaperScissors.Move.Paper, SALT_A),
            keccak256(abi.encodePacked(alice, uint8(2), SALT_A))
        );
    }

    function testHiddenStakeMustMatch() public {
        bytes32 c = _commit(alice, 1, SALT_A);
        vm.prank(alice);
        vm.expectRevert(RockPaperScissors.WrongStake.selector);
        game.join{value: STAKE - 1}(c);
        vm.prank(alice);
        vm.expectRevert(RockPaperScissors.WrongStake.selector);
        game.join{value: STAKE + 1}(c);
        vm.prank(alice);
        vm.expectRevert(RockPaperScissors.InvalidCommitment.selector);
        game.join{value: STAKE}(bytes32(0));
    }

    function testHiddenSamePlayerCannotTakeBothSeats() public {
        vm.prank(alice);
        game.join{value: STAKE}(_commit(alice, 1, SALT_A));
        vm.prank(alice);
        vm.expectRevert(RockPaperScissors.AlreadyJoined.selector);
        game.join{value: STAKE}(_commit(alice, 2, SALT_B));
    }

    function testHiddenThirdPlayerCannotJoin() public {
        vm.prank(alice);
        game.join{value: STAKE}(_commit(alice, 1, SALT_A));
        vm.prank(bob);
        game.join{value: STAKE}(_commit(bob, 1, SALT_B));
        vm.prank(carol);
        vm.expectRevert(RockPaperScissors.WrongPhase.selector);
        game.join{value: STAKE}(_commit(carol, 1, SALT_A));

        vm.prank(carol);
        vm.expectRevert(RockPaperScissors.NotPlayer.selector);
        game.reveal(RockPaperScissors.Move.Rock, SALT_A);
    }

    function testHiddenCopiedCommitmentCannotBeRevealed() public {
        bytes32 c = _commit(alice, 1, SALT_A);
        vm.prank(alice);
        game.join{value: STAKE}(c);
        // Bob copies Alice's commitment hoping to replay her reveal and force a draw.
        vm.prank(bob);
        game.join{value: STAKE}(c);

        vm.prank(alice);
        game.reveal(RockPaperScissors.Move.Rock, SALT_A);
        vm.prank(bob);
        vm.expectRevert(RockPaperScissors.CommitmentMismatch.selector);
        game.reveal(RockPaperScissors.Move.Rock, SALT_A);

        vm.warp(block.timestamp + REVEAL_PERIOD);
        game.settle();
        assertEq(game.winner(), alice);
    }

    function testHiddenCannotRevealDifferentMove() public {
        vm.prank(alice);
        game.join{value: STAKE}(_commit(alice, 1, SALT_A));
        vm.prank(bob);
        game.join{value: STAKE}(_commit(bob, 3, SALT_B));

        // Bob sees nothing yet, but tries to switch from Scissors to Paper anyway.
        vm.prank(bob);
        vm.expectRevert(RockPaperScissors.CommitmentMismatch.selector);
        game.reveal(RockPaperScissors.Move.Paper, SALT_B);

        vm.prank(bob);
        vm.expectRevert(RockPaperScissors.InvalidMove.selector);
        game.reveal(RockPaperScissors.Move.None, SALT_B);
    }

    function testHiddenDoubleRevealReverts() public {
        vm.prank(alice);
        game.join{value: STAKE}(_commit(alice, 1, SALT_A));
        vm.prank(bob);
        game.join{value: STAKE}(_commit(bob, 3, SALT_B));
        vm.prank(alice);
        game.reveal(RockPaperScissors.Move.Rock, SALT_A);
        vm.prank(alice);
        vm.expectRevert(RockPaperScissors.AlreadyRevealed.selector);
        game.reveal(RockPaperScissors.Move.Rock, SALT_A);
    }

    function testHiddenRevealBeforeSecondPlayerReverts() public {
        vm.prank(alice);
        game.join{value: STAKE}(_commit(alice, 1, SALT_A));
        vm.prank(alice);
        vm.expectRevert(RockPaperScissors.WrongPhase.selector);
        game.reveal(RockPaperScissors.Move.Rock, SALT_A);

        vm.expectRevert(RockPaperScissors.WrongPhase.selector);
        game.settle();
    }

    function testHiddenRevealAtDeadlineReverts() public {
        vm.prank(alice);
        game.join{value: STAKE}(_commit(alice, 1, SALT_A));
        vm.prank(bob);
        game.join{value: STAKE}(_commit(bob, 2, SALT_B));
        uint256 deadline = game.revealDeadline();

        vm.warp(deadline - 1);
        vm.prank(alice);
        game.reveal(RockPaperScissors.Move.Rock, SALT_A);

        vm.expectRevert(RockPaperScissors.RevealPending.selector);
        game.settle();

        vm.warp(deadline);
        vm.prank(bob);
        vm.expectRevert(RockPaperScissors.RevealClosed.selector);
        game.reveal(RockPaperScissors.Move.Paper, SALT_B);

        game.settle();
        assertEq(game.winner(), alice);
        assertEq(game.winnings(alice), 2 * STAKE);
        assertEq(game.winnings(bob), 0);
    }

    function testHiddenNobodyRevealsRefundsBoth() public {
        vm.prank(alice);
        game.join{value: STAKE}(_commit(alice, 1, SALT_A));
        vm.prank(bob);
        game.join{value: STAKE}(_commit(bob, 2, SALT_B));

        vm.expectRevert(RockPaperScissors.RevealPending.selector);
        game.settle();

        vm.warp(block.timestamp + REVEAL_PERIOD + 1);
        game.settle();
        assertEq(game.winner(), address(0));
        assertEq(game.winnings(alice), STAKE);
        assertEq(game.winnings(bob), STAKE);
    }

    function testHiddenSettleOnlyOnce() public {
        _play(game, 1, 3);
        vm.expectRevert(RockPaperScissors.WrongPhase.selector);
        game.settle();
        assertEq(game.winnings(alice), 2 * STAKE);

        vm.prank(alice);
        game.withdraw();
        vm.prank(alice);
        vm.expectRevert(RockPaperScissors.NothingToWithdraw.selector);
        game.withdraw();
        vm.prank(bob);
        vm.expectRevert(RockPaperScissors.NothingToWithdraw.selector);
        game.withdraw();

        assertEq(alice.balance, 11 ether);
        assertEq(bob.balance, 9 ether);
        assertEq(address(game).balance, 0);
    }

    function testHiddenLeaveFreesTheSeat() public {
        vm.prank(alice);
        game.join{value: STAKE}(_commit(alice, 1, SALT_A));

        vm.prank(bob);
        vm.expectRevert(RockPaperScissors.NotPlayer.selector);
        game.leave();

        vm.prank(alice);
        game.leave();
        assertEq(game.player1(), address(0));
        assertEq(game.commitments(alice), bytes32(0));
        vm.prank(alice);
        game.withdraw();
        assertEq(alice.balance, 10 ether);

        vm.prank(alice);
        vm.expectRevert(RockPaperScissors.NotPlayer.selector);
        game.leave();

        // A fresh pair can use the game.
        vm.prank(bob);
        game.join{value: STAKE}(_commit(bob, 2, SALT_B));
        vm.prank(carol);
        game.join{value: STAKE}(_commit(carol, 1, SALT_A));
        assertEq(game.player1(), bob);
        assertEq(game.player2(), carol);

        vm.prank(bob);
        vm.expectRevert(RockPaperScissors.WrongPhase.selector);
        game.leave();
    }
}
