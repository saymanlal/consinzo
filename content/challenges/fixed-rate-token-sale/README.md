# Build a Fixed-Rate Token Sale with Caps

## Problem Statement

Implement `TokenSale` in `src/TokenSale.sol`. Buyers send ETH and immediately receive ERC-20
tokens at a fixed rate. The sale is limited by a global hard cap and a per-buyer limit, both
expressed in wei. The deployer is the owner and is the only account that can withdraw the ETH.

The sale contract does not mint. It sells tokens that were transferred to it beforehand.

## Interface

```solidity
constructor(address token_, uint256 rate_, uint256 hardCap_, uint256 buyerLimit_)

function tokensFor(uint256 weiAmount) public view returns (uint256)
function remainingCap() external view returns (uint256)
function buy() external payable
function withdraw() external
```

Public state (already declared in the starter): `token`, `owner`, `rate`, `hardCap`,
`buyerLimit`, `totalRaised`, `contributed(address)`.

## Rules

1. `rate` is the number of token base units sold per 1 ETH:
   `tokensFor(weiAmount) = weiAmount * rate / 1e18` (rounded down).
2. `buy()`:
   - reverts with `ZeroAmount()` if `msg.value == 0`;
   - reverts with `HardCapExceeded()` if `totalRaised + msg.value > hardCap`;
   - reverts with `BuyerLimitExceeded()` if `contributed[msg.sender] + msg.value > buyerLimit`;
   - the checks are evaluated in that order;
   - increases `totalRaised` and `contributed[msg.sender]` by `msg.value`;
   - transfers `tokensFor(msg.value)` tokens to the buyer and reverts with `TransferFailed()`
     if the token returns `false`;
   - emits `Purchased(buyer, weiPaid, tokensOut)`.
3. A purchase that reaches a cap exactly is valid.
4. `remainingCap()` returns `hardCap - totalRaised`.
5. `withdraw()`:
   - reverts with `NotOwner()` unless called by `owner`;
   - sends the entire ETH balance of the contract to `owner`, reverting with
     `TransferFailed()` if the send fails;
   - emits `Withdrawn(owner, amount)`;
   - does not change `totalRaised` (the hard cap is a lifetime cap).

## What the tests check

- Token amounts for several contribution sizes, including ones that round down.
- Cumulative accounting across several buyers and repeated purchases.
- Exact-cap boundaries for both caps and the documented order of checks.
- Owner-only withdrawal and that withdrawing does not reopen the hard cap.
