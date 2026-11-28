# Commit-Reveal Games: Background

## The problem

Every transaction and every storage slot on a public chain is visible. In a game with simultaneous
moves, whoever moves second simply reads the first move and answers it. Marking a variable
`private` does not help; it only stops other contracts from reading it.

## Commit-reveal

The standard fix splits each move into two transactions:

1. **Commit**: publish `hash(move, secret)`. The hash fixes the move without disclosing it.
2. **Reveal**: publish `move` and `secret`. The contract recomputes the hash and accepts the move
   only if it matches.

Requirements for the hash input:

- a secret with enough entropy (a random 32-byte salt), because the set of possible moves is tiny
  and could otherwise be brute-forced;
- something that ties the commitment to its author (the sender address), so that a copied
  commitment cannot be opened by the copier.

## The last-revealer problem

After one player reveals, the other knows the outcome before deciding whether to reveal. If
refusing to reveal had no cost, a losing player would always refuse. Commit-reveal protocols
therefore attach a deadline and a penalty: here, failing to reveal forfeits the stake.

## State machines

Solidity has no built-in state machine, but an `enum` phase variable plus a check at the top of
each function gives the same effect. Keep the transitions few and make each one happen in exactly
one function.
