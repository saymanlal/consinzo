import { near, assertEq, assertThrows } from "near-sdk-js";
import { DaoVoting } from "../../src/DaoVoting";

export function testHiddenDoubleVotingAndPrematureFinalizeBlocked(): void {
  near._setContext({ predecessorAccountId: "council.testnet", blockTimestamp: 1000n });
  const dao = new DaoVoting(50n);
  dao.setMemberWeight("alice.testnet", 30n);
  dao.setMemberWeight("bob.testnet", 30n);

  near._setContext({ predecessorAccountId: "alice.testnet", blockTimestamp: 1000n });
  const id = dao.createProposal("Upgrade router", 400n);
  dao.vote(id, true);
  assertThrows(() => dao.vote(id, true), "Already voted");

  // Premature finalize before deadline (1400n) must throw
  near._setContext({ blockTimestamp: 1400n });
  assertThrows(() => dao.finalize(id));

  // Voting after deadline must throw
  near._setContext({ predecessorAccountId: "bob.testnet", blockTimestamp: 1401n });
  assertThrows(() => dao.vote(id, true));

  // Insufficient quorum (30n < 50n) must finalize as false
  const passed = dao.finalize(id);
  assertEq(passed, false);
  assertEq(dao.getProposal(id)?.finalized, true);
  assertThrows(() => dao.finalize(id));
}

export function testHiddenTieAndOwnerOnlyWeightAssignment(): void {
  near._setContext({ predecessorAccountId: "council.testnet", blockTimestamp: 100n });
  const dao = new DaoVoting(30n);

  near._setContext({ predecessorAccountId: "attacker.testnet" });
  assertThrows(() => dao.setMemberWeight("attacker.testnet", 1000n));

  near._setContext({ predecessorAccountId: "council.testnet" });
  dao.setMemberWeight("alice.testnet", 40n);
  dao.setMemberWeight("bob.testnet", 40n);

  near._setContext({ predecessorAccountId: "alice.testnet", blockTimestamp: 100n });
  const id = dao.createProposal("Tie test", 100n);
  dao.vote(id, true);
  near._setContext({ predecessorAccountId: "bob.testnet", blockTimestamp: 150n });
  dao.vote(id, false);

  near._setContext({ blockTimestamp: 201n });
  // Quorum met (40 >= 30) but tie (40 yes == 40 no) must fail simple majority
  assertEq(dao.finalize(id), false);
}
