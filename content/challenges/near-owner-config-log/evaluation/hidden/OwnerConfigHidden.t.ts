import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { OwnerConfig } from "../../src/OwnerConfig";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testHiddenNoChangeIsRejectedAndNotLogged(): void {
  ctx("owner.testnet");
  const config = new OwnerConfig();
  config.setValue("mode", "open");
  assertThrows(() => config.setValue("mode", "open"), "No change");
  assertEq(config.changeCount(), 1);
  // Changing back and forth is logged each time.
  assertEq(config.setValue("mode", "closed"), 1);
  assertEq(config.setValue("mode", "open"), 2);
  assertEq(config.getChange(2)?.oldValue, "closed");
  assertEq(config.getChange(3), null);
}

export function testHiddenEmptyValueIsDistinctFromMissing(): void {
  ctx("owner.testnet");
  const config = new OwnerConfig();
  // Setting an empty string on a missing key is a real change.
  assertEq(config.setValue("note", ""), 0);
  assertEq(config.getValue("note"), "");
  assertEq(config.getChange(0)?.oldValue, null);
  assertThrows(() => config.setValue("note", ""), "No change");
  assertEq(config.setValue("note", "x"), 1);
  assertEq(config.getChange(1)?.oldValue, "");
  assertThrows(() => config.setValue("", "x"), "Invalid key");
  assertEq(config.changeCount(), 2);
}

export function testHiddenOwnershipTransferMovesRights(): void {
  ctx("owner.testnet");
  const config = new OwnerConfig();
  config.setValue("a", "1");

  ctx("mallory.testnet");
  assertThrows(() => config.transferOwnership("mallory.testnet"), "Only owner");
  ctx("owner.testnet");
  assertThrows(() => config.transferOwnership(""), "Invalid owner");
  config.transferOwnership("next.testnet");
  assertEq(config.getOwner(), "next.testnet");
  assertEq(config.changeCount(), 1);

  // The previous owner is locked out, the new owner can write.
  assertThrows(() => config.setValue("a", "2"), "Only owner");
  ctx("next.testnet", 900n);
  assertEq(config.setValue("a", "2"), 1);
  assertEq(config.getChange(1)?.changedBy, "next.testnet");
  assertEq(config.getChange(1)?.timestamp, 900n);
}

export function testHiddenOwnerCheckComesFirst(): void {
  ctx("owner.testnet");
  const config = new OwnerConfig();
  config.setValue("k", "v");
  ctx("mallory.testnet");
  // Invalid arguments from a non-owner still report the authorisation failure.
  assertThrows(() => config.setValue("", "v"), "Only owner");
  assertThrows(() => config.setValue("k", "v"), "Only owner");
  assertThrows(() => config.transferOwnership(""), "Only owner");
  assertEq(config.getOwner(), "owner.testnet");
}

export function testHiddenIndependentKeys(): void {
  ctx("owner.testnet");
  const config = new OwnerConfig();
  config.setValue("a", "1");
  config.setValue("b", "1");
  config.setValue("a", "2");
  assertEq(config.getValue("a"), "2");
  assertEq(config.getValue("b"), "1");
  assertEq(config.getChange(1)?.key, "b");
  assertEq(config.getChange(1)?.oldValue, null);
  assertEq(config.getChange(2)?.oldValue, "1");
  assertEq(config.changeCount(), 3);
}
