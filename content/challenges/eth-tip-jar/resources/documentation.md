# Receiving and Sending ETH: Background

## payable

A function must be marked `payable` to accept ETH. Inside it `msg.value` is the amount sent, in
wei. A call that sends value to a non-payable function reverts.

## receive()

```solidity
receive() external payable { ... }
```

`receive` runs when the contract is called with empty calldata, which is what a plain ETH transfer
from a wallet is. Without `receive` (or a payable `fallback`) such transfers revert. `receive`
takes no arguments and returns nothing, but it can read `msg.sender` and `msg.value` and may revert.

## Sending ETH

```solidity
(bool ok, ) = recipient.call{value: amount}("");
if (!ok) revert TransferFailed();
```

A low-level `call` forwards all remaining gas and returns `false` instead of reverting when the
recipient fails, so the result must be checked. `address(this).balance` is the contract's current
balance in wei.

## Events

Events write to the transaction log. They are cheap, cannot be read by contracts, and are the
standard way for off-chain software to follow what a contract did. Up to three parameters can be
`indexed` so that clients can filter on them.

## Ether units

`1 ether == 1e18` wei. Literals such as `0.5 ether` are converted by the compiler.
