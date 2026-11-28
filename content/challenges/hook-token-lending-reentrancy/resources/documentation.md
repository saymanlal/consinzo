# Token hooks and reentrancy in lending code

## Tokens that call back

Plain ERC-20 transfers only change balances. Several token designs add callbacks:

- **ERC-777** calls `tokensToSend` on the sender and `tokensReceived` on the recipient when
  they have registered an implementer in the ERC-1820 registry.
- **ERC-677 / ERC-1363** offer `transferAndCall` variants.
- **ERC-721 and ERC-1155** safe transfers call the recipient.

A protocol that lists such a token performs an external call to a user-controlled contract
every time it moves the token, even though the code only says `token.transfer(...)`.
Historic incidents on lending markets and AMMs that listed ERC-777 tokens followed exactly
this shape.

## Why checked arithmetic is not a defence

Overflow checks catch `x -= amount` when `x` is too small. They do not catch code that
caches a value, makes a call and then writes the cached result back. They also do nothing
for other functions that read the not-yet-updated value during the call.

## Defensive structure

1. **Checks**: validate inputs and the resulting position.
2. **Effects**: write every storage variable that describes the new position.
3. **Interactions**: move tokens last.

Add a contract-wide reentrancy lock to all functions that change positions. One lock for the
whole contract is what prevents cross-function reentrancy; separate locks per function do
not.

## Verifying a fix

Write attack contracts whose hook calls each public function of the pool in turn inside
`try/catch`, and assert invariants afterwards:

- token balance of the pool equals the booked total;
- no position exceeds its borrowing limit;
- the attacker's token balance did not grow.
