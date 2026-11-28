# Patch a Lending Pool Re-entered Through Token Transfer Hooks

`HookLendingPool` is a single-market lending pool. Users deposit `collateralToken` and may
borrow `debtToken` up to 50% (`LTV_BPS = 5000`) of their collateral. Both tokens are valued
1:1.

The collateral token is hook-enabled in the style of ERC-777: after a transfer it calls
`onTokenReceived(from, amount)` on recipients that registered for it. That call happens
inside `transfer`, before `transfer` returns to the pool.

`withdrawCollateral` computes the caller's remaining collateral, sends the tokens and only
then writes the new balance. While the recipient's hook runs, the pool still shows the old
position. From the hook a borrower can:

- call `withdrawCollateral` again and be paid a second time, with the difference coming out
  of other users' collateral; or
- call `borrow` against collateral that is already on its way out, leaving debt without
  backing.

## Your task

Patch `src/HookLendingPool.sol` so that no hook, at any nesting depth and through any
function, can observe or exploit unfinished accounting. Keep signatures, errors and events.

## Behaviour that must hold

- `depositCollateral(amount)`, `borrow(amount)`, `repay(amount)` and
  `withdrawCollateral(amount)` keep their current semantics for honest users, including
  contract wallets whose hook does nothing harmful.
- Reverts: `ZeroAmount()` for zero amounts; `Unhealthy()` when a borrow or withdrawal would
  leave `debtOf[user] > maxDebtFor(collateralOf[user])`; `InsufficientCollateral()` when
  withdrawing more than the balance; `RepayExceedsDebt()` when repaying more than owed.
- A position exactly at the limit (`debt == maxDebtFor(collateral)`) is allowed.
- Invariants after every transaction, including ones that tried to re-enter:
  - `collateralToken.balanceOf(pool) == totalCollateral` (as long as nobody donates tokens);
  - `totalCollateral` equals the sum of all `collateralOf` balances;
  - for every user, `debtOf[user] <= maxDebtFor(collateralOf[user])`;
  - a user never receives more collateral than they deposited.
- A nested call made from a hook may revert or may execute against the updated state. Both
  are fine if the invariants hold. The attack contracts in the tests wrap the nested call in
  `try/catch`, so the outer withdrawal must still complete correctly.

## What the tests check

Public tests cover the normal lifecycle, the LTV limit on borrow and withdraw, and a
contract that re-enters `withdrawCollateral` from its hook. Hidden tests add a contract that
borrows from inside the hook, nested partial withdrawals several levels deep, an honest
hooked wallet, exact LTV boundaries and input validation.
