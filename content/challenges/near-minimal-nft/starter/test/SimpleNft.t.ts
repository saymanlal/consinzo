import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { SimpleNft } from "../src/SimpleNft";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testMinterMintsToken(): void {
  ctx("minter.testnet");
  const nft = new SimpleNft();
  nft.mint("token-1", "alice.testnet");
  assertEq(nft.ownerOf("token-1"), "alice.testnet");
  assertEq(nft.balanceOf("alice.testnet"), 1);
  assertEq(nft.totalSupply(), 1);
  assertEq(nft.ownerOf("token-2"), null);
}

export function testOnlyMinterCanMint(): void {
  ctx("minter.testnet");
  const nft = new SimpleNft();
  ctx("alice.testnet");
  assertThrows(() => nft.mint("token-1", "alice.testnet"), "Only minter");
  assertEq(nft.totalSupply(), 0);
  assertEq(nft.ownerOf("token-1"), null);
}

export function testOwnerTransfersToken(): void {
  ctx("minter.testnet");
  const nft = new SimpleNft();
  nft.mint("token-1", "alice.testnet");
  ctx("alice.testnet");
  nft.transfer("token-1", "bob.testnet");
  assertEq(nft.ownerOf("token-1"), "bob.testnet");
  assertEq(nft.balanceOf("alice.testnet"), 0);
  assertEq(nft.balanceOf("bob.testnet"), 1);
  assertEq(nft.totalSupply(), 1);
}

export function testNonOwnerCannotTransfer(): void {
  ctx("minter.testnet");
  const nft = new SimpleNft();
  nft.mint("token-1", "alice.testnet");
  ctx("bob.testnet");
  assertThrows(() => nft.transfer("token-1", "bob.testnet"), "Not token owner");
  assertEq(nft.ownerOf("token-1"), "alice.testnet");
}
