# TWAP Oracle with a Ring Buffer of Observations

## Problem Statement

Implement `TwapOracle` in `src/TwapOracle.sol`. A trusted feeder (the deployer) pushes spot
prices. The oracle keeps a fixed-size ring buffer of cumulative-price observations and
returns the time-weighted average price (TWAP) over any window that the buffer still covers.

## Definitions

- `price` is the current spot price. It applies from the moment it is set until the next update.
- The *cumulative price* at time `t` is the sum over all elapsed seconds of the price that was
  in force during that second. It is `0` at deployment.
- An *observation* is a pair `(timestamp, cumulative)` recorded at the start of an update,
  before the new price takes effect.

## Required Interface

```solidity
error NotOwner();
error ZeroCardinality();
error ObservationTooOld();

event PriceUpdated(uint256 price, uint256 cumulative, uint256 timestamp);

constructor(uint16 cardinality_, uint256 initialPrice);

function owner() external view returns (address);
function cardinality() external view returns (uint16); // ring size, immutable
function index() external view returns (uint16);       // slot of the newest observation
function count() external view returns (uint16);       // live observations, <= cardinality
function price() external view returns (uint256);
function observations(uint256 slot) external view returns (uint64 timestamp, uint192 cumulative);

function update(uint256 newPrice) external;
function currentCumulative() external view returns (uint256);
function oldestTimestamp() external view returns (uint64);
function consult(uint32 secondsAgo) external view returns (uint256);
```

## Rules

1. The constructor reverts with `ZeroCardinality` when `cardinality_ == 0`. It sets `owner`
   to the deployer, stores `initialPrice`, and writes the first observation
   `(block.timestamp, 0)` into slot `0`. After construction `index == 0` and `count == 1`.
2. `update(newPrice)` is restricted to `owner` (`NotOwner` otherwise).
   - If `block.timestamp` is greater than the newest observation's timestamp, a new
     observation is written to slot `(index + 1) % cardinality` with
     `cumulative = newest.cumulative + price * elapsed` (using the price in force *before*
     this update). `index` advances to that slot and `count` grows by one until it reaches
     `cardinality`; after that the oldest observation is overwritten.
   - If `block.timestamp` equals the newest observation's timestamp, no observation is
     written and `index` / `count` do not change.
   - In both cases `price` becomes `newPrice` and `PriceUpdated(newPrice, cumulative, block.timestamp)`
     is emitted with the newest observation's cumulative value.
3. `currentCumulative()` returns `newest.cumulative + price * (block.timestamp - newest.timestamp)`.
4. `oldestTimestamp()` returns the timestamp of the oldest observation still in the buffer.
5. `consult(secondsAgo)`:
   - `secondsAgo == 0` returns the spot `price`.
   - Otherwise let `target = block.timestamp - secondsAgo`. If `target` is earlier than
     `oldestTimestamp()` (or `secondsAgo` exceeds `block.timestamp`), revert with
     `ObservationTooOld`.
   - The cumulative value at `target` is:
     - `newest.cumulative + price * (target - newest.timestamp)` if `target >= newest.timestamp`;
     - otherwise, with `a` the latest observation with `a.timestamp <= target` and `b` the
       next observation after it,
       `a.cumulative + (b.cumulative - a.cumulative) * (target - a.timestamp) / (b.timestamp - a.timestamp)`
       (integer division, rounds down).
   - The result is `(currentCumulative() - cumulativeAt(target)) / secondsAgo`, rounded down.

## What the Tests Check

- Averages over windows that end now and start exactly on, between and after observations.
- Ring wrap-around: the oldest observation is overwritten, `oldestTimestamp` moves forward
  and windows that are no longer covered revert with `ObservationTooOld`.
- Same-timestamp updates replace the price without consuming a slot.
- Access control, a ring of size one, and exact rounding.
