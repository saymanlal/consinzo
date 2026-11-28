# Median Oracle Aggregator with Staleness and Deviation Checks

## Problem Statement

A single price reporter is a single point of failure. An aggregator lets several
independent reporters push prices and publishes their **median**, which a minority of
faulty or malicious reporters cannot move outside the range of the honest reports. The
median is only meaningful if enough recent reports exist and if enough of them agree with
it, so the aggregator also enforces a maximum age and a maximum deviation.

Implement `MedianOracle` in `src/MedianOracle.sol`. There are no external contracts: the
reporters are plain addresses that call `report`.

## Interface

```solidity
uint256 public constant MAX_REPORTERS = 16;
uint256 public constant BPS = 10_000;

constructor(address[] memory reporters_, uint256 minReports_, uint256 maxAge_, uint256 maxDeviationBps_)

function owner() external view returns (address);
function minReports() external view returns (uint256);
function maxAge() external view returns (uint256);
function maxDeviationBps() external view returns (uint256);
function isReporter(address account) external view returns (bool);
function reporterCount() external view returns (uint256);
function reports(address reporter) external view returns (uint128 price, uint64 updatedAt);

function addReporter(address reporter) external;      // owner only
function removeReporter(address reporter) external;   // owner only
function report(uint256 price) external;              // reporters only

function freshCount() external view returns (uint256);
function latestPrice() external view returns (uint256);
function tryLatestPrice() external view returns (bool ok, uint256 price);

event Reported(address indexed reporter, uint256 price);
event ReporterAdded(address indexed reporter);
event ReporterRemoved(address indexed reporter);

error NotOwner();
error NotReporter();
error ZeroAddress();
error DuplicateReporter();
error TooManyReporters();
error InvalidConfig();
error InvalidPrice();
error InsufficientReports();
error DeviationTooHigh();
```

## Rules

### Configuration

1. The deployer becomes `owner`. `minReports`, `maxAge` (seconds) and `maxDeviationBps`
   are fixed at construction.
2. The constructor reverts with:
   - `TooManyReporters()` if more than `MAX_REPORTERS` reporters are given;
   - `ZeroAddress()` if a reporter is `address(0)`;
   - `DuplicateReporter()` if a reporter appears twice;
   - `InvalidConfig()` if `minReports_ == 0`, `minReports_ > reporters_.length`,
     `maxAge_ == 0`, `maxDeviationBps_ == 0` or `maxDeviationBps_ > BPS`.
3. `addReporter` (owner only, else `NotOwner()`) reverts with `ZeroAddress()`,
   `DuplicateReporter()` if the address is already a reporter, or `TooManyReporters()` if
   the set already holds `MAX_REPORTERS`. A newly added reporter has no report.
4. `removeReporter` (owner only, else `NotOwner()`) reverts with `NotReporter()` if the
   address is not a reporter and with `InvalidConfig()` if the removal would leave fewer
   than `minReports` reporters. Removal deletes the reporter's stored report: it stops
   counting immediately and does not come back if the address is added again.

### Reporting

5. `report(price)` reverts with `NotReporter()` for any other caller, then with
   `InvalidPrice()` if `price == 0` or `price > type(uint128).max`. It replaces the
   caller's previous report with `(price, block.timestamp)` and emits `Reported`. Each
   reporter has at most one report.

### Reading

A report is **fresh** when it exists and `block.timestamp - updatedAt <= maxAge` (a report
that is exactly `maxAge` old is fresh). `freshCount()` returns the number of fresh reports.

6. `latestPrice()`:
   1. Reverts with `InsufficientReports()` if `freshCount() < minReports`.
   2. Computes the median of the fresh prices: with an odd count the middle value of the
      sorted prices; with an even count the average of the two middle values, rounded down.
   3. A fresh report is **in agreement** when
      `|price - median| * BPS <= median * maxDeviationBps`. Reverts with
      `DeviationTooHigh()` if fewer than `minReports` fresh reports are in agreement.
   4. Returns the median. Outliers do not change the result as long as the agreement
      quorum is met.
7. `tryLatestPrice()` never reverts. It returns `(true, median)` when `latestPrice()` would
   succeed and `(false, 0)` otherwise.

## What the tests check

- Medians of odd and even numbers of reports submitted in any order, including rounding.
- Overwriting a report instead of counting it twice.
- Fresh / stale boundaries and recovery after a new report.
- The agreement quorum at its exact boundary, outliers being ignored when the quorum holds,
  and a minority being unable to move the median outside the honest range.
- Reporter management: access control, duplicates, the cap, the `minReports` floor and
  removal wiping the stored report.
- Constructor validation and input validation in `report`.
