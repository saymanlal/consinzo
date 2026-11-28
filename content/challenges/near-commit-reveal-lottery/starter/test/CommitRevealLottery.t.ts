import { near, assertEq, assertThrows } from "near-sdk-js";
import { CommitRevealLottery, hashCommitment } from "../src/CommitRevealLottery";

const PRICE = 100n;
const BOND = 10n;

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

export function testAllRevealWinnerTakesPot(): void {
  const lottery = setup();
  join(lottery, "alice.testnet", 5n, "a");
  join(lottery, "bob.testnet", 9n, "b");
  join(lottery, "carol.testnet", 3n, "c");
  assertEq(lottery.playerCount(), 3);

  time(2000n);
  caller("bob.testnet");
  lottery.reveal(9n, "b");
  assertEq(lottery.balanceOf("bob.testnet"), BOND);
  caller("carol.testnet");
  lottery.reveal(3n, "c");
  caller("alice.testnet");
  lottery.reveal(5n, "a");
  assertEq(lottery.revealCount(), 3);

  // 9 ^ 3 ^ 5 = 15, 15 % 3 = 0 -> first revealer.
  time(3000n);
  assertEq(lottery.finalize(), "bob.testnet");
  assertEq(lottery.getWinner(), "bob.testnet");
  assertEq(lottery.balanceOf("bob.testnet"), 310n);
  assertEq(lottery.balanceOf("alice.testnet"), 10n);

  caller("bob.testnet");
  assertEq(lottery.withdraw(), 310n);
  assertThrows(() => lottery.withdraw(), "Nothing to withdraw");
}

export function testNoRevealForfeitsBondToPot(): void {
  const lottery = setup();
  join(lottery, "alice.testnet", 5n, "a");
  join(lottery, "bob.testnet", 9n, "b");
  join(lottery, "carol.testnet", 3n, "c");

  time(2500n);
  caller("alice.testnet");
  lottery.reveal(5n, "a");
  caller("bob.testnet");
  lottery.reveal(9n, "b");

  // 5 ^ 9 = 12, 12 % 2 = 0 -> alice. Carol's bond joins the pot.
  time(3001n);
  assertEq(lottery.finalize(), "alice.testnet");
  assertEq(lottery.balanceOf("alice.testnet"), 10n + 300n + 10n);
  assertEq(lottery.balanceOf("bob.testnet"), 10n);
  assertEq(lottery.balanceOf("carol.testnet"), 0n);
  assertEq(lottery.hasRevealed("carol.testnet"), false);
}

export function testRevealMustMatchCommitment(): void {
  const lottery = setup();
  join(lottery, "alice.testnet", 5n, "a");

  time(2000n);
  caller("alice.testnet");
  assertThrows(() => lottery.reveal(6n, "a"), "Commitment mismatch");
  assertThrows(() => lottery.reveal(5n, "wrong"), "Commitment mismatch");
  lottery.reveal(5n, "a");
  assertThrows(() => lottery.reveal(5n, "a"), "Already revealed");
}

export function testPhaseBoundaries(): void {
  const lottery = setup();
  join(lottery, "alice.testnet", 5n, "a");

  caller("alice.testnet");
  time(1999n);
  assertThrows(() => lottery.reveal(5n, "a"), "Not in reveal phase");
  time(2000n);
  caller("bob.testnet", PRICE + BOND);
  assertThrows(() => lottery.commit(hashCommitment("bob.testnet", 1n, "b")), "Commit phase over");
  time(2999n);
  assertThrows(() => lottery.finalize(), "Reveal phase not over");
}
