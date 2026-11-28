# Solution Explanation: Commit-Reveal Lottery

## Phases
Two timestamps define three half-open intervals: commit `[deploy, commitEnd)`, reveal `[commitEnd, revealEnd)`, settle `[revealEnd, ∞)`. Every method starts with its phase check, so a seed can never be revealed while others can still commit, and the winner can never be computed while others can still reveal.

## Commitments
`reveal` recomputes `hashCommitment(caller, seed, salt)` and compares it with the stored value. The account id is part of the preimage, so copying another player's commitment gains nothing: the copier cannot produce a matching reveal and loses the bond. The salt prevents brute-forcing small seeds during the commit phase.

## Randomness and the penalty
The combined seed is the XOR of all revealed seeds. As long as one revealer chose a seed the others could not predict, the result is unpredictable at commit time. The remaining attack is selective abort: the last revealer knows the outcome and can refuse to reveal. The bond makes that refusal cost money, and the forfeited bond goes to the pot so the remaining players are compensated. The winner is drawn from the revealers only, so a non-revealer can never win.

## Accounting
Every deposit is `ticketPrice + bond`. Revealers receive their bond at reveal time, the winner receives all ticket prices plus the bonds of non-revealers, and when nobody reveals each player receives the full deposit. In every path the sum of credited balances equals the sum of deposits, which the hidden tests assert.

## Pitfalls
- Using `<=` on the wrong side of a phase boundary creates a timestamp at which both commit and reveal are allowed.
- Indexing the winner by commit order instead of reveal order can select a player who never revealed.
- Setting `finalized` after crediting makes a repeated `finalize` pay the pot again.
- A negative seed would make the XOR negative and the modulo index negative; it is rejected.
