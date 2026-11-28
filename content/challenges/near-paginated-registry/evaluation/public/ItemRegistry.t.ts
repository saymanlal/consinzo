import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { ItemRegistry } from "../src/ItemRegistry";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

function seed(registry: ItemRegistry, count: number, account: string = "alice.testnet"): void {
  ctx(account);
  for (let i = 0; i < count; i++) registry.addItem("item-" + i);
}

export function testAddItemAssignsIds(): void {
  const registry = new ItemRegistry();
  ctx("alice.testnet");
  assertEq(registry.addItem("first"), 0);
  ctx("bob.testnet");
  assertEq(registry.addItem("second"), 1);
  assertEq(registry.totalItems(), 2);
  assertEq(registry.getItem(1)?.owner, "bob.testnet");
  assertEq(registry.getItem(1)?.name, "second");
  assertEq(registry.getItem(2), null);
}

export function testGetItemsReturnsRequestedPage(): void {
  const registry = new ItemRegistry();
  seed(registry, 10);
  const page = registry.getItems(3, 4);
  assertEq(page.length, 4);
  assertEq(page.map((i) => i.id).join(","), "3,4,5,6");
  assertEq(page[0]?.name, "item-3");
}

export function testLastPageIsPartial(): void {
  const registry = new ItemRegistry();
  seed(registry, 10);
  const page = registry.getItems(8, 5);
  assertEq(page.map((i) => i.id).join(","), "8,9");
  assertEq(registry.getItems(10, 5).length, 0);
}

export function testInvalidArgumentsRejected(): void {
  const registry = new ItemRegistry();
  seed(registry, 3);
  assertThrows(() => registry.getItems(-1, 2), "Invalid from_index");
  assertThrows(() => registry.getItems(0, 0), "Invalid limit");
}
