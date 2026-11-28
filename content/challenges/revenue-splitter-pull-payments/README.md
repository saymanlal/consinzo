# Share-Based Revenue Splitter with Pull Payments

## Problem Statement

Implement `RevenueSplitter` in `src/RevenueSplitter.sol`. The contract receives ETH at any time
and splits everything it has ever received among a fixed set of payees in proportion to their
shares. Payments are pulled: each payee's portion is sent only when `release` is called for that
payee.

## Interface

```solidity
constructor(address[] memory payees_, uint256[] memory shares_) payable
receive() external payable

function payeeCount() external view returns (uint256)
function payee(uint256 index) external view returns (address)
function totalReceived() public view returns (uint256)
function releasable(address account) public view returns (uint256)
function release(address account) external returns (uint256 amount)
```

Public state declared in the starter: `totalShares`, `totalReleased`, `shares(address)`,
`released(address)`.

## Rules

1. The constructor reverts with:
   - `InvalidPayees()` if the arrays are empty or have different lengths;
   - `ZeroAddress()` if a payee is `address(0)`;
   - `ZeroShares()` if a share entry is `0`;
   - `DuplicatePayee()` if an address appears twice.
   It stores the payees in order and sets `totalShares` to the sum of the shares. ETH sent with
   the constructor counts as received revenue.
2. `receive()` accepts ETH and emits `PaymentReceived(from, amount)`.
3. `totalReceived()` is `address(this).balance + totalReleased`.
4. `releasable(account)` is
   `totalReceived() * shares[account] / totalShares - released[account]` (integer division,
   rounded down). It is `0` for an address that is not a payee.
5. `release(account)` can be called by anyone. It:
   - reverts with `NotPayee()` if `shares[account] == 0`;
   - reverts with `NothingDue()` if `releasable(account) == 0`;
   - adds the amount to `released[account]` and `totalReleased`;
   - sends the amount to `account` and reverts with `TransferFailed()` if the send fails;
   - emits `PaymentReleased(account, amount)` and returns the amount.
6. A payee that cannot receive ETH must not prevent other payees from being paid.

## What the tests check

- Proportional splits for several share configurations, including rounding dust.
- Correct cumulative accounting when revenue arrives between releases.
- Constructor validation and the `release` revert paths.
- That a reverting payee blocks only itself.
