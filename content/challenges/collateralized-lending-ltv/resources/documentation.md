# Collateralised Borrowing Basics

## Loan-to-value

A lending protocol accepts collateral worth `V` and lets the user owe at most `V * LTV`. With
an LTV of 75%, collateral worth 2000 supports up to 1500 of debt. The gap is the safety margin
that protects lenders if the collateral loses value.

## Pricing with integers

Token amounts are integers in base units. A price is stored as a fixed-point number: here it is
"debt base units per `1e18` collateral base units". The value of `c` units of collateral is
`c * price / 1e18`. Percentages are stored in basis points (1/10,000).

Integer division truncates, so every formula has a rounding direction. Protocol-side limits
(how much may be borrowed) must round down; requirements (how much collateral must stay) must
round up. A simple way to stay consistent is to express every check with the same limit
function instead of deriving an inverse formula.

## State transitions

| Action              | Collateral | Debt | Needs a solvency check |
|---------------------|-----------:|-----:|:----------------------:|
| deposit collateral  | up         | -    | no                     |
| borrow              | -          | up   | yes                    |
| repay               | -          | down | no                     |
| withdraw collateral | down       | -    | yes                    |

## Liquidity

Being allowed to borrow is different from the pool having the tokens. A borrow can fail for
either reason and it helps integrators if the two are reported differently.

This exercise has no interest and no liquidations; those are layered on top of exactly this
accounting.
