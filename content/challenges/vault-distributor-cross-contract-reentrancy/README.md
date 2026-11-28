# Patch Cross-Contract Reentrancy Between a Vault and Its Reward Distributor

Two contracts in `src/RewardDistributor.sol` work together:

- `StakeVault` holds staked ETH (`deposit`, `withdraw`) and is the source of truth for
  `balanceOf` and `totalStaked`.
- `RewardDistributor` holds reward ETH. `fund()` increases `accRewardPerShare`; a staker's
  claimable amount is `pending(user) = balanceOf(user) * accRewardPerShare / 1e18 -
  rewardDebt[user]`.

Whenever a stake changes, the vault calls `distributor.settle(user)` first (pay what was
earned on the old stake) and `distributor.sync(user)` afterwards (reset `rewardDebt` for the
new stake). Stakers can also call `distributor.claim()` directly.

Both contracts have a `nonReentrant` modifier, but each lock only covers its own contract.
The distributor sends ETH before it updates `rewardDebt`, and while that payment is in
flight the staker can enter the *other* contract:

- from the payment made by `claim()`, call `vault.withdraw` or `vault.deposit`; the vault
  calls `settle`, which pays the same pending reward again;
- from the payment made by `settle()` during a vault operation, call `distributor.claim()`,
  whose lock is free at that moment.

Every extra payout is taken from rewards owed to other stakers.

## Your task

Patch the file so that a reward is paid at most once, no matter which contract or function
the recipient re-enters from its `receive` function. You may change either contract, but
keep all existing external signatures, errors and events, and keep the vault as the only
caller of `settle` and `sync` (`NotVault()` otherwise).

## Behaviour that must hold

- `fund()` reverts with `NothingStaked()` when `totalStaked == 0`; otherwise rewards are
  split pro rata among current stakers.
- `claim()` pays `pending(msg.sender)` and leaves `pending(msg.sender) == 0`.
- `deposit` and `withdraw` first pay the rewards earned so far, then change the stake. A
  staker who joins later earns only from later funding.
- For any sequence of calls, including nested ones, the total ETH a staker receives as
  rewards never exceeds their pro-rata share, and the distributor always holds enough ETH to
  pay every other staker's `pending` amount.
- A nested call may revert or complete; the tests wrap nested calls in `try/catch` and check
  balances afterwards.

## What the tests check

Public tests check pro-rata splitting, withdrawal with rewards, repeated claims, and an
attacker that withdraws from the vault during the payment of `claim()`. Hidden tests attack
in the opposite direction (claim during the vault's `settle` payment), re-enter through
`deposit`, and verify accounting for late stakers, top-ups, hook access control and funding
with no stake.
