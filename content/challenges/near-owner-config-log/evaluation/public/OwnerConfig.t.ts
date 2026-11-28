import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { OwnerConfig } from "../src/OwnerConfig";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testOwnerSetsValueAndLogsChange(): void {
  ctx("owner.testnet", 100n);
  const config = new OwnerConfig();
  ctx("owner.testnet", 200n);
  assertEq(config.setValue("fee", "30"), 0);

  assertEq(config.getValue("fee"), "30");
  assertEq(config.changeCount(), 1);
  const change = config.getChange(0);
  assertEq(change?.key, "fee");
  assertEq(change?.oldValue, null);
  assertEq(change?.newValue, "30");
  assertEq(change?.changedBy, "owner.testnet");
  assertEq(change?.timestamp, 200n);
}

export function testNonOwnerCannotSetValue(): void {
  ctx("owner.testnet");
  const config = new OwnerConfig();
  ctx("mallory.testnet");
  assertThrows(() => config.setValue("fee", "0"), "Only owner");
  assertEq(config.getValue("fee"), null);
  assertEq(config.changeCount(), 0);
}

export function testUpdateRecordsOldValue(): void {
  ctx("owner.testnet");
  const config = new OwnerConfig();
  config.setValue("fee", "30");
  assertEq(config.setValue("fee", "45"), 1);
  assertEq(config.getChange(1)?.oldValue, "30");
  assertEq(config.getChange(1)?.newValue, "45");
  assertEq(config.getValue("fee"), "45");
}
