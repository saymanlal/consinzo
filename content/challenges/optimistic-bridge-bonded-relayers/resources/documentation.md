# Background: Optimistic Verification

## The idea

Verifying a message from another chain on-chain is expensive or impossible without a light
client. Optimistic systems replace verification with an economic game:

1. An **asserter** posts a claim and a bond.
2. During a **challenge period** anyone can dispute the claim by posting a bond of their own.
3. If there is no dispute, the claim is accepted when the period ends.
4. If there is a dispute, some mechanism decides who is right. The loser's bond goes to the
   winner.

The system is safe as long as at least one honest party watches the claims and the bond is
large enough to make false claims unprofitable.

## Identifying a message

A source message is identified by where it came from and its sequence number, not by its
content. Keying claims by `(source chain, nonce)` means two relayers cannot have two
different claims about the same message live at once, and a finalized message cannot be
finalized a second time with different content.

## Bond symmetry

Both sides should risk the same amount. If the challenger risks less than the asserter,
spam disputes are cheap; if more, false claims are cheap to make and expensive to fight.

## Separating funds

A contract that holds user liquidity, security deposits and unpaid balances must track
each separately. `address(this).balance` only tells you the total.

## Pull payments

Sending ETH inside a state transition lets the recipient run code in the middle of it and
lets a reverting recipient block the transition. Recording a credit and letting the
recipient collect it later removes both problems. The withdrawal itself must clear the
credit before transferring.
