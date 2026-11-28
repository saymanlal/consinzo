# Immutable and Constant Fee Configuration

## Problem Statement

Implement `FeeConfig` in `src/FeeConfig.sol`. The contract holds a fee setting that is fixed for
the lifetime of the deployment. Limits that are the same for every deployment are `constant`;
values chosen by the deployer are validated in the constructor and stored as `immutable`.

## Required Interface

```solidity
uint256 public constant BPS_DENOMINATOR = 10_000;
uint256 public constant MAX_FEE_BPS = 1_000;      // 10%
uint256 public constant LOCK_PERIOD = 7 days;

address public immutable treasury;
uint256 public immutable feeBps;
uint256 public immutable deployedAt;

error ZeroTreasury();
error FeeTooHigh(uint256 feeBps, uint256 maxFeeBps);

constructor(address treasury_, uint256 feeBps_);

function feeFor(uint256 amount) external view returns (uint256);
function netAmount(uint256 amount) external view returns (uint256);
function unlockTime() external view returns (uint256);
function isUnlocked() external view returns (bool);
```

## Rules

1. The constructor reverts with `ZeroTreasury()` when `treasury_ == address(0)`.
2. The constructor reverts with `FeeTooHigh(feeBps_, MAX_FEE_BPS)` when `feeBps_ > MAX_FEE_BPS`.
   A fee of exactly `MAX_FEE_BPS` is allowed, and so is a fee of zero. The treasury check runs
   first.
3. `treasury` and `feeBps` hold the constructor arguments. `deployedAt` is `block.timestamp` at
   construction.
4. `feeFor(amount)` returns `amount * feeBps / BPS_DENOMINATOR`, rounded down.
5. `netAmount(amount)` returns `amount - feeFor(amount)`, so fee plus net always equals `amount`.
6. `unlockTime()` returns `deployedAt + LOCK_PERIOD`.
7. `isUnlocked()` returns `true` once `block.timestamp >= unlockTime()`.

The constants and the three immutables are already declared in the starter. Do not change their
names, types or values.

## What the Tests Check

- The constants and the stored configuration.
- Both constructor revert paths, including the error arguments, and the boundary fee values.
- Fee and net amounts for ordinary, tiny and very large inputs.
- The unlock time and the lock boundary.
