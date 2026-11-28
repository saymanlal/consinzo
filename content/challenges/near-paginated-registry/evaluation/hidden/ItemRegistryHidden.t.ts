import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { ItemRegistry } from "../../src/ItemRegistry";

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

export function testHiddenLimitIsCappedAtMaxPageSize(): void {
  const registry = new ItemRegistry();
  seed(registry, 120);
  assertEq(registry.getItems(0, 1000).length, 50);
  assertEq(registry.getItems(0, 51).length, 50);
  assertEq(registry.getItems(0, 50).length, 50);
  assertEq(registry.getItems(0, 49).length, 49);
  const capped = registry.getItems(60, 500);
  assertEq(capped.length, 50);
  assertEq(capped[0]?.id, 60);
  assertEq(capped[49]?.id, 109);
  // Near the end the remaining item count wins over the cap.
  assertEq(registry.getItems(100, 500).length, 20);
}

export function testHiddenBoundsAndEmptyRegistry(): void {
  const registry = new ItemRegistry();
  assertEq(registry.getItems(0, 10).length, 0);
  assertEq(registry.getItemsByOwner("alice.testnet", 0, 10).length, 0);
  seed(registry, 5);
  assertEq(registry.getItems(4, 1).length, 1);
  assertEq(registry.getItems(4, 10)[0]?.id, 4);
  assertEq(registry.getItems(5, 1).length, 0);
  assertEq(registry.getItems(5000, 10).length, 0);
  assertEq(registry.getItems(0, 5).length, 5);
}

export function testHiddenArgumentValidation(): void {
  const registry = new ItemRegistry();
  seed(registry, 5);
  assertThrows(() => registry.getItems(1.5, 2), "Invalid from_index");
  assertThrows(() => registry.getItems(0, -3), "Invalid limit");
  assertThrows(() => registry.getItems(0, 2.5), "Invalid limit");
  // from_index is validated first, also when it is beyond the end.
  assertThrows(() => registry.getItems(-1, 0), "Invalid from_index");
  assertThrows(() => registry.getItems(99, 0), "Invalid limit");
  assertThrows(() => registry.getItemsByOwner("alice.testnet", -1, 1), "Invalid from_index");
  assertThrows(() => registry.getItemsByOwner("alice.testnet", 0, 0), "Invalid limit");
  assertThrows(() => registry.addItem(""), "Invalid name");
  assertEq(registry.totalItems(), 5);
}

export function testHiddenWalkingPagesCoversEverythingOnce(): void {
  const registry = new ItemRegistry();
  seed(registry, 23);
  const seen: number[] = [];
  let from = 0;
  let rounds = 0;
  while (rounds < 20) {
    const page = registry.getItems(from, 7);
    if (page.length === 0) break;
    for (const item of page) seen.push(item.id);
    from += page.length;
    rounds += 1;
  }
  assertEq(rounds, 4);
  assertEq(seen.length, 23);
  for (let i = 0; i < 23; i++) assertEq(seen[i], i);
}

export function testHiddenOwnerPaginationWithInterleavedOwners(): void {
  const registry = new ItemRegistry();
  // Global ids: alice gets the even ids, bob the odd ones, then carol one item.
  for (let i = 0; i < 6; i++) {
    ctx("alice.testnet");
    registry.addItem("a" + i);
    ctx("bob.testnet");
    registry.addItem("b" + i);
  }
  ctx("carol.testnet");
  registry.addItem("c0");

  assertEq(registry.itemCountOf("alice.testnet"), 6);
  assertEq(registry.itemCountOf("bob.testnet"), 6);
  assertEq(registry.itemCountOf("carol.testnet"), 1);
  assertEq(registry.itemCountOf("dave.testnet"), 0);
  assertEq(registry.totalItems(), 13);

  const bobPage = registry.getItemsByOwner("bob.testnet", 2, 3);
  assertEq(bobPage.map((i) => i.name).join(","), "b2,b3,b4");
  assertEq(bobPage.map((i) => i.id).join(","), "5,7,9");
  assertEq(bobPage[0]?.owner, "bob.testnet");

  assertEq(registry.getItemsByOwner("alice.testnet", 4, 10).map((i) => i.id).join(","), "8,10");
  assertEq(registry.getItemsByOwner("alice.testnet", 6, 10).length, 0);
  assertEq(registry.getItemsByOwner("carol.testnet", 0, 1)[0]?.id, 12);
  assertEq(registry.getItemsByOwner("dave.testnet", 0, 5).length, 0);
}

export function testHiddenOwnerPaginationIsCapped(): void {
  const registry = new ItemRegistry();
  seed(registry, 70, "alice.testnet");
  seed(registry, 3, "bob.testnet");
  assertEq(registry.getItemsByOwner("alice.testnet", 0, 999).length, 50);
  assertEq(registry.getItemsByOwner("alice.testnet", 30, 999).length, 40);
  assertEq(registry.getItemsByOwner("bob.testnet", 0, 999).length, 3);
  assertEq(registry.getItemsByOwner("bob.testnet", 1, 999)[0]?.id, 71);
}
