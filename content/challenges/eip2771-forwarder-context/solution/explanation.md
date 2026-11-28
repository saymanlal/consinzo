# Reference Solution Explanation

All behaviour hangs on one predicate:

```solidity
msg.sender == trustedForwarder && msg.data.length >= 20
```

When it holds, `_msgSender()` returns the last 20 bytes of calldata as an address and
`_msgData()` returns the calldata without them. Otherwise both return the plain `msg.sender`
and `msg.data`.

Every function uses `_msgSender()` where a normal contract would use `msg.sender`:

- `transferOwnership` compares it with `owner`;
- `deposit` and `setNote` use it as the account key;
- `withdraw` debits it and sends the ether to it. Sending to `msg.sender` would pay the
  forwarder for relayed withdrawals.

`withdraw` updates the balance before the external call, so a re-entrant call sees the
reduced balance.

## Pitfalls

- Reading the suffix without checking `msg.sender`. Anyone can append bytes to calldata;
  the ABI decoder ignores trailing data, so the call still succeeds and the attacker
  becomes whoever they name.
- Skipping the length check. A call from the forwarder with fewer than 20 bytes would
  underflow in the slice arithmetic or read garbage.
- Mixing `msg.sender` and `_msgSender()` inside one function, for example authorising
  with one and paying out to the other.
- Trusting any contract that "looks like" a forwarder. Only the address fixed at
  construction is trusted.
