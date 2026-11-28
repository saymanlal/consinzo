# Time in Solidity: Background

## block.timestamp

`block.timestamp` is the Unix time, in seconds, of the block that contains the transaction. All
transactions in one block see the same value. It only moves forward. The block proposer chooses it
within narrow limits, so it is suitable for deadlines measured in minutes or longer, not for
precise timing or randomness.

## Time units

Solidity provides the suffixes `seconds`, `minutes`, `hours`, `days` and `weeks`. They are plain
multipliers: `1 days == 86400`. A point in time is computed as `block.timestamp + 30 days`.

## Timestamp versus duration

An interface must be clear about which one it expects. This contract takes an absolute timestamp.
Validating that it lies in the future catches the common mistake of passing a duration, since a
value such as `2592000` (30 days) lies far in the past as a timestamp.

## Boundaries

Decide whether a deadline is inclusive and use the same comparison everywhere. Here "unlocked"
means `block.timestamp >= unlockTime` in the view and in the withdrawal check.

## Unsigned subtraction

`a - b` reverts when `b > a`. A "time remaining" function must return zero explicitly once the
deadline has passed.

## Immutables as commitments

A value declared `immutable` cannot be changed by any function. For a time lock this is what makes
the lock credible: the owner cannot bring the date forward.
