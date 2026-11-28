# Liquidity-Network Bridge Pool

## Problem Statement

A canonical bridge is slow. A liquidity network makes it feel fast: on the destination
chain a pool of LP capital pays the user straight away, minus a fee, and is repaid in full
when the canonical bridge finally delivers the user's funds. LPs earn the fee for lending
their capital over that gap.

Implement `FastBridgePool` in `src/FastBridgePool.sol`: the destination-side pool for one
ERC-20 token. The source chain is not simulated. Two trusted addresses stand in for it:

- the `relayer` reports that a user started a transfer and asks the pool to front it
  (`fulfill`);
- the `settler` is the canonical bridge delivering the user's funds later (`settle`). It
  holds the tokens and has approved the pool.

## Interface

```solidity
enum State { None, Fulfilled, Settled }

constructor(address token_, address relayer_, address settler_, uint256 feeBps_, uint256 protocolShareBps_)

// configuration (immutable): token, owner (= deployer), relayer, settler, feeBps, protocolShareBps

function idle() external view returns (uint256);
function outstanding() external view returns (uint256);
function protocolFees() external view returns (uint256);
function totalShares() external view returns (uint256);
function sharesOf(address lp) external view returns (uint256);

function totalAssets() external view returns (uint256);
function convertToShares(uint256 assets) external view returns (uint256);
function convertToAssets(uint256 shares) external view returns (uint256);
function deposit(uint256 assets) external returns (uint256 shares);
function withdraw(uint256 shares) external returns (uint256 assets);

function quoteFee(uint256 amount) external view returns (uint256);
function transferState(bytes32 transferId) external view returns (State);
function fulfill(bytes32 transferId, address recipient, uint256 amount) external returns (uint256 paid); // relayer
function settle(bytes32 transferId, address recipient, uint256 amount) external;                         // settler
function withdrawProtocolFees(address to) external returns (uint256 amount);                             // owner
```

Errors: `InvalidConfig`, `NotOwner`, `NotRelayer`, `NotSettler`, `ZeroAddress`,
`ZeroAmount`, `ZeroShares`, `InsufficientShares`, `InsufficientIdleLiquidity`,
`AlreadyHandled`, `AlreadySettled`, `TermsMismatch`, `TransferFailed`.

## Rules

### Configuration

1. The constructor reverts with `InvalidConfig()` if any address is zero, if
   `feeBps_ > 1_000`, or if `protocolShareBps_ > 10_000`.

### Accounting model

2. The pool keeps three counters of tokens:
   - `idle` – tokens it can use now;
   - `outstanding` – tokens it paid to users and has not been repaid, valued at what it
     paid;
   - `protocolFees` – the protocol's share of realised fees.
3. `totalAssets() == idle + outstanding`. It is computed from the counters, never from
   `token.balanceOf`. Tokens sent to the pool outside its functions do not change any
   counter or the share price. `protocolFees` is not part of `totalAssets`.

### LP shares

4. `convertToShares(assets)` is `assets` when `totalShares == 0`, otherwise
   `assets * totalShares / totalAssets()` rounded down. `convertToAssets(shares)` is `0`
   when `totalShares == 0`, otherwise `shares * totalAssets() / totalShares` rounded down.
5. `deposit(assets)`: `assets == 0` -> `ZeroAmount()`; the share amount would be zero ->
   `ZeroShares()`. Mints `convertToShares(assets)` shares, adds `assets` to `idle`, pulls
   the tokens from the caller.
6. `withdraw(shares)`: `shares == 0` -> `ZeroAmount()`; more than the caller holds ->
   `InsufficientShares()`; the asset value exceeds `idle` -> `InsufficientIdleLiquidity()`.
   Burns the shares, removes `convertToAssets(shares)` from `idle` and transfers it.
   Capital that is outstanding cannot be withdrawn until it is settled.

### Fulfilment (fast path)

7. `quoteFee(amount) == amount * feeBps / 10_000`, rounded down.
8. `fulfill` checks, in order: caller is the relayer (`NotRelayer()`);
   `recipient != address(0)` (`ZeroAddress()`); `amount != 0` (`ZeroAmount()`); the
   transfer's state is `None` (`AlreadyHandled()`); `paid = amount - quoteFee(amount)` is
   at most `idle` (`InsufficientIdleLiquidity()`).
9. It transfers `paid` to the recipient, moves `paid` from `idle` to `outstanding`, sets
   the state to `Fulfilled` and returns `paid`. `totalAssets()` does not change: the fee is
   not earned until settlement.

### Settlement

10. `settle` checks, in order: caller is the settler (`NotSettler()`);
    `recipient != address(0)` (`ZeroAddress()`); `amount != 0` (`ZeroAmount()`); the state
    is not `Settled` (`AlreadySettled()`).
11. If the transfer was `Fulfilled`: `(recipient, amount)` must equal the values given to
    `fulfill`, otherwise `TermsMismatch()` and nothing changes. The pool pulls `amount`
    from the settler. With `fee = amount - paid` and
    `protocolCut = fee * protocolShareBps / 10_000` (rounded down): `outstanding` drops by
    `paid`, `idle` grows by `amount - protocolCut`, `protocolFees` grows by `protocolCut`.
12. If the transfer was never fulfilled (slow path): the pool pulls `amount` from the
    settler and transfers all of it to `recipient`. No fee is charged and no counter
    changes.
13. In both cases the state becomes `Settled`. A settled transfer can be neither settled
    nor fulfilled again.

### Protocol fees

14. `withdrawProtocolFees` checks: owner (`NotOwner()`), `to != address(0)`
    (`ZeroAddress()`), non-zero balance (`ZeroAmount()`); then zeroes `protocolFees` and
    transfers that amount.

**Invariant.** `token.balanceOf(pool) >= idle + protocolFees`, with equality when nobody
has sent tokens to the pool directly.

## What the tests check

Share pricing before and after fees are realised, rounding direction, deposits and
withdrawals while capital is outstanding, the slow path, every ordering of `fulfill` and
`settle` for one id, mismatched settlements, donation resistance, protocol fee separation,
access control, and the balance invariant after mixed sequences.
