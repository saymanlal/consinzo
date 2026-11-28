# Fix a Fee That Rounds to Zero

`PaymentRouter` forwards ETH payments to a payee and keeps a protocol fee, expressed in
basis points (1 bps = 0.01%), for the treasury.

The fee is computed as `amount / 10_000 * feeBps`. Integer division truncates, so every
payment below 10 000 wei pays no fee at all and every other payment is charged only on
the part of the amount that is a multiple of 10 000. Splitting a payment into small
pieces avoids the fee completely.

## Your task

Patch `starter/src/PaymentRouter.sol` so the fee is computed with full precision.

## Required interface (unchanged)

```solidity
error FeeTooHigh();
error ZeroAddress();
error ZeroAmount();
error NotTreasury();
error NothingToWithdraw();
error TransferFailed();

uint256 public constant BPS = 10_000;
uint256 public constant MAX_FEE_BPS = 1_000;

constructor(address treasury_, uint256 feeBps_);

function treasury() external view returns (address);
function feeBps() external view returns (uint256);
function accruedFees() external view returns (uint256);

function quoteFee(uint256 amount) external view returns (uint256);
function pay(address payee) external payable;
function withdrawFees() external;
```

## Rules

- `quoteFee(amount)` returns `floor(amount * feeBps / 10_000)`.
- `pay(payee)` charges `quoteFee(msg.value)`, adds it to `accruedFees` and forwards
  `msg.value - fee` to `payee`. Fee plus forwarded amount always equals `msg.value`.
- `pay` reverts with `ZeroAmount()` for zero value, `ZeroAddress()` for a zero payee and
  `TransferFailed()` if the payee rejects the ETH.
- `withdrawFees()` is callable only by `treasury` (`NotTreasury()` otherwise), sends
  `accruedFees` to it and resets the counter. It reverts with `NothingToWithdraw()` when
  no fees are accrued.
- The constructor reverts with `FeeTooHigh()` above `MAX_FEE_BPS` and `ZeroAddress()` for
  a zero treasury.

## What the tests check

- Exact fees for amounts below 10 000 wei and for amounts that are not multiples of
  10 000.
- Many small payments accrue the same total fee as the rules above imply.
- Payee amounts, fee withdrawal and the revert conditions.
