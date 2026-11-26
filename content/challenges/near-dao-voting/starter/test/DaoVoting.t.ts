import { near, assertEq, assertThrows } from "near-sdk-js";
import { DaoVoting } from "../src/DaoVoting";

export function testCreateVoteAndFinalizePass(): void {
  near._setContext({ predecessorAccountId: "council.testnet", blockTimestamp: 1000n });
  const dao = new DaoVoting(50n);
  dao.setMemberWeight("alice.testnet", 40n);
  dao.setMemberWeight("bob.testnet", 25n);
  dao.setMemberWeight("carol.testnet", 20n);

  near._setContext({ predecessorAccountId: "alice.testnet", blockTimestamp: 1000n });
  const id = dao.createProposal("Fund ecosystem grant", 500n);
  assertEq(id, 1);

  dao.vote(id, true);
  near._setContext({ predecessorAccountId: "bob.testnet", blockTimestamp: 1200n });
  dao.vote(id, true);
  near._setContext({ predecessorAccountId: "carol.testnet", blockTimestamp: 1400n });
  dao.vote(id, false);

  near._setContext({ blockTimestamp: 1501n });
  const passed = dao.finalize(id);
  assertEq(passed, true);
  assertEq(dao.getProposal(id)?.yesWeight, 65n);
  assertEq(dao.getProposal(id)?.noWeight, 20n);
}

export function testNonMemberCannotPropose(): void {
  near._setContext({ predecessorAccountId: "council.testnet", blockTimestamp: 1000n });
  const dao = new DaoVoting(50n);
  near._setContext({ predecessorAccountId: "outsider.testnet" });
  assertThrows(() => dao.createProposal("Spam", 100n));
}
