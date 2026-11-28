# Reference Solution Explanation

## Structure

The game is a three-state machine:

```
Waiting --(second join)--> Reveal --(settle)--> Finished
```

- In `Waiting`, seats are filled and `player1` may still leave.
- In `Reveal`, each player may open their commitment until `revealDeadline`.
- `settle` is the only transition to `Finished`, and it is the only place where the pot is
  assigned. Because it requires `phase == Reveal` and immediately sets `Finished`, it runs once.

## The commitment

`keccak256(abi.encodePacked(player, uint8(move), salt))`

- The **salt** is necessary because there are only three moves: without it, anyone can hash the
  three candidates and read the move from the commitment.
- The **player address** is necessary because commitments are public. Without it the second player
  can submit the same commitment as the first and, after the first player reveals, replay the same
  `(move, salt)` to guarantee a draw.

## Settlement cases

| Reveals in | Result |
| --- | --- |
| both | compare moves: `(3 + m1 - m2) % 3` is `0` draw, `1` player1 wins, `2` player2 wins |
| one (after deadline) | the revealer takes the pot |
| none (after deadline) | both get their stake back |

Settling early is allowed as soon as both moves are in; otherwise it must wait for the deadline.

## Pitfalls

- **No timeout.** A player who sees the opponent's revealed move and knows they lost has no reason
  to reveal. Without the forfeit rule both stakes would be locked forever.
- **Reveal after the deadline.** If late reveals were accepted, a player could wait for the
  deadline, look at the opponent's move and still choose whether to reveal. The deadline closes
  `reveal` and opens `settle` at the same instant.
- **`Move.None` as a reveal.** It must be rejected, since `None` is the marker for "not revealed".
- **Push payments in `settle`.** Paying the winner directly would let a losing contract player
  block settlement in a draw. Winnings are credited and withdrawn separately.
