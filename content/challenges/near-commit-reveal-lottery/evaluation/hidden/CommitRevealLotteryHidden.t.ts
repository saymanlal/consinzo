import { near, assertEq, assertThrows } from "near-sdk-js";
import { CommitRevealLottery, hashCommitment } from "../../src/CommitRevealLottery";

const PRICE = 100n;
const BOND = 25n;

function caller(who: string, deposit: bigint = 0n): void {
  near._setContext({ predecessorAccountId: who, signerAccountId: who, attachedDeposit: deposit });
}

function time(now: bigint): void {
  near._setContext({ blockTimestamp: now });
}

function setup(): CommitRevealLottery {
  time(1000n);
  caller("house.testnet");
  return new CommitRevealLottery(PRICE, BOND, 2000n, 3000n);
}

function join(lottery: CommitRevealLottery, who: string, seed: bigint, salt: string): void {
  caller(who, PRICE + BOND);
  lottery.commit(hashCommitment(who, seed, salt));
}

export function testHiddenCopiedCommitmentCannotBeRevealed(): void {
  const lottery = setup();
  join(lottery, "alice.testnet", 7n, "s1");
  // Mallory copies Alice's commitment from the chain.
  caller("mallory.testnet", PRICE + BOND);
  lottery.commit(hashCommitment("alice.testnet", 7n, "s1"));

  time(2100n);
  caller("alice.testnet");
  lottery.reveal(7n, "s1");
  caller("mallory.testnet");
  assertThrows(() => lottery.reveal(7n, "s1"), "Commitment mismatch");
  assertEq(lottery.hasRevealed("mallory.testnet"), false);

  time(3000n);
  assertEq(lottery.finalize(), "alice.testnet");
  // Two tickets, Mallory's forfeited bond, plus Alice's own returned bond.
  assertEq(lottery.balanceOf("alice.testnet"), 200n + 25n + 25n);
  assertEq(lottery.balanceOf("mallory.testnet"), 0n);
}

export function testHiddenWinnerIndexFollowsRevealOrder(): void {
  const lottery = setup();
  join(lottery, "alice.testnet", 7n, "a");
  join(lottery, "bob.testnet", 2n, "b");
  join(lottery, "carol.testnet", 12n, "c");
  join(lottery, "dave.testnet", 1n, "d");

  time(2000n);
  caller("carol.testnet");
  lottery.reveal(12n, "c");
  caller("alice.testnet");
  lottery.reveal(7n, "a");
  caller("bob.testnet");
  lottery.reveal(2n, "b");

  // 12 ^ 7 ^ 2 = 9, 9 % 3 = 0 -> carol (first revealer), not alice (first committer).
  time(4000n);
  assertEq(lottery.finalize(), "carol.testnet");
  assertEq(lottery.balanceOf("carol.testnet"), 25n + 400n + 25n);
  assertEq(lottery.isFinalized(), true);
  assertThrows(() => lottery.finalize(), "Already finalized");

  const total =
    lottery.balanceOf("alice.testnet") +
    lottery.balanceOf("bob.testnet") +
    lottery.balanceOf("carol.testnet") +
    lottery.balanceOf("dave.testnet");
  assertEq(total, 4n * (PRICE + BOND));
}

export function testHiddenSecondRevealerCanWin(): void {
  const lottery = setup();
  join(lottery, "alice.testnet", 6n, "a");
  join(lottery, "bob.testnet", 3n, "b");
  time(2000n);
  caller("alice.testnet");
  lottery.reveal(6n, "a");
  caller("bob.testnet");
  lottery.reveal(3n, "b");
  // 6 ^ 3 = 5, 5 % 2 = 1 -> bob.
  time(3000n);
  assertEq(lottery.finalize(), "bob.testnet");
  assertEq(lottery.balanceOf("bob.testnet"), 225n);
  assertEq(lottery.balanceOf("alice.testnet"), 25n);
}

export function testHiddenNobodyRevealsRefundsEveryone(): void {
  const lottery = setup();
  join(lottery, "alice.testnet", 7n, "a");
  join(lottery, "bob.testnet", 2n, "b");
  assertEq(lottery.getWinner(), "");

  time(3000n);
  caller("alice.testnet");
  assertThrows(() => lottery.reveal(7n, "a"), "Not in reveal phase");
  assertEq(lottery.finalize(), "");
  assertEq(lottery.getWinner(), "");
  assertEq(lottery.balanceOf("alice.testnet"), 125n);
  assertEq(lottery.balanceOf("bob.testnet"), 125n);
  caller("bob.testnet");
  assertEq(lottery.withdraw(), 125n);
  assertEq(lottery.balanceOf("bob.testnet"), 0n);
  assertThrows(() => lottery.finalize(), "Already finalized");
  assertEq(lottery.balanceOf("alice.testnet"), 125n);
}

export function testHiddenCommitValidation(): void {
  const lottery = setup();
  caller("alice.testnet", PRICE);
  assertThrows(() => lottery.commit(hashCommitment("alice.testnet", 1n, "a")), "Wrong deposit");
  caller("alice.testnet", PRICE + BOND + 1n);
  assertThrows(() => lottery.commit(hashCommitment("alice.testnet", 1n, "a")), "Wrong deposit");
  caller("alice.testnet", PRICE + BOND);
  assertThrows(() => lottery.commit(""), "Invalid commitment");
  lottery.commit(hashCommitment("alice.testnet", 1n, "a"));
  assertThrows(() => lottery.commit(hashCommitment("alice.testnet", 2n, "z")), "Already committed");
  assertEq(lottery.playerCount(), 1);

  time(2000n);
  caller("bob.testnet");
  assertThrows(() => lottery.reveal(1n, "a"), "No commitment");
  assertEq(lottery.revealCount(), 0);
}

export function testHiddenConstructorValidation(): void {
  time(1000n);
  caller("house.testnet");
  assertThrows(() => new CommitRevealLottery(0n, BOND, 2000n, 3000n), "Invalid config");
  assertThrows(() => new CommitRevealLottery(PRICE, 0n, 2000n, 3000n), "Invalid config");
  assertThrows(() => new CommitRevealLottery(PRICE, BOND, 1000n, 3000n), "Invalid config");
  assertThrows(() => new CommitRevealLottery(PRICE, BOND, 2000n, 2000n), "Invalid config");
}
