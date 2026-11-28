# NEAR One-Account-One-Vote Poll

## Objective
Implement `Poll` in `src/Poll.ts`. The poll is created with a fixed list of option labels. Each account can vote for one option, once.

## Interface

```ts
constructor(options: string[])
vote(option: number): void
tally(option: number): number
totalVotes(): number
hasVoted(account: string): boolean
choiceOf(account: string): number | null
optionCount(): number
optionLabel(option: number): string
leading(): number
```

## Rules
1. The constructor requires at least 2 options, every label non-empty and all labels distinct. Otherwise it throws an error containing `Invalid options`. The poll keeps its own copy of the labels.
2. `vote(option)` records the vote of `near.predecessorAccountId()`.
   - `option` must be an integer with `0 <= option < optionCount()`, otherwise throw an error containing `Invalid option`.
   - If the caller already voted, throw an error containing `Already voted`. The first vote stands; it cannot be changed.
3. `tally(option)` returns the number of votes for a valid option and throws `Invalid option` for an invalid index. `optionLabel(option)` behaves the same way for labels.
4. `totalVotes()` returns the number of votes cast.
5. `hasVoted(account)` and `choiceOf(account)` report a voter's status; `choiceOf` returns `null` for an account that has not voted.
6. `leading()` returns the index of the option with the most votes. On a tie it returns the lowest index among the tied options. With no votes it returns `-1`.

## What the tests check
Tallies, double-vote rejection (including for voters of option 0), invalid indices, constructor validation, the tie rule of `leading()` and that later changes to the array passed to the constructor do not affect the poll.
