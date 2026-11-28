import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { SimpleNft } from "../../src/SimpleNft";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testHiddenDuplicateMintRejected(): void {
  ctx("minter.testnet");
  const nft = new SimpleNft();
  nft.mint("a", "alice.testnet");
  assertThrows(() => nft.mint("a", "bob.testnet"), "Token already exists");
  assertEq(nft.ownerOf("a"), "alice.testnet");
  assertEq(nft.balanceOf("bob.testnet"), 0);
  assertEq(nft.totalSupply(), 1);

  // A transferred token id is still taken.
  ctx("alice.testnet");
  nft.transfer("a", "carol.testnet");
  ctx("minter.testnet");
  assertThrows(() => nft.mint("a", "alice.testnet"), "Token already exists");
  assertEq(nft.totalSupply(), 1);
}

export function testHiddenPreviousOwnerAndMinterCannotMoveToken(): void {
  ctx("minter.testnet");
  const nft = new SimpleNft();
  nft.mint("a", "alice.testnet");
  // The minter does not own the token it minted for Alice.
  assertThrows(() => nft.transfer("a", "minter.testnet"), "Not token owner");

  ctx("alice.testnet");
  nft.transfer("a", "bob.testnet");
  assertThrows(() => nft.transfer("a", "alice.testnet"), "Not token owner");
  assertEq(nft.ownerOf("a"), "bob.testnet");

  ctx("bob.testnet");
  nft.transfer("a", "alice.testnet");
  assertEq(nft.ownerOf("a"), "alice.testnet");
  assertEq(nft.balanceOf("alice.testnet"), 1);
  assertEq(nft.balanceOf("bob.testnet"), 0);
}

export function testHiddenValidationOrder(): void {
  ctx("minter.testnet");
  const nft = new SimpleNft();
  assertThrows(() => nft.mint("", "alice.testnet"), "Invalid token id");
  assertThrows(() => nft.mint("a", ""), "Invalid receiver");
  assertThrows(() => nft.mint("", ""), "Invalid token id");
  nft.mint("a", "alice.testnet");
  assertThrows(() => nft.mint("a", ""), "Invalid receiver");

  ctx("bob.testnet");
  assertThrows(() => nft.mint("", ""), "Only minter");
  assertThrows(() => nft.transfer("missing", "bob.testnet"), "Token not found");
  assertThrows(() => nft.transfer("a", ""), "Not token owner");

  ctx("alice.testnet");
  assertThrows(() => nft.transfer("a", ""), "Invalid receiver");
  assertThrows(() => nft.transfer("a", "alice.testnet"), "Cannot transfer to self");
  assertEq(nft.balanceOf("alice.testnet"), 1);
  assertEq(nft.ownerOf("a"), "alice.testnet");
}

export function testHiddenBalancesMatchSupply(): void {
  ctx("minter.testnet");
  const nft = new SimpleNft();
  nft.mint("1", "alice.testnet");
  nft.mint("2", "alice.testnet");
  nft.mint("3", "bob.testnet");
  nft.mint("4", "minter.testnet");
  nft.transfer("4", "bob.testnet");

  ctx("alice.testnet");
  nft.transfer("1", "bob.testnet");
  ctx("bob.testnet");
  nft.transfer("3", "carol.testnet");

  assertEq(nft.balanceOf("alice.testnet"), 1);
  assertEq(nft.balanceOf("bob.testnet"), 2);
  assertEq(nft.balanceOf("carol.testnet"), 1);
  assertEq(nft.balanceOf("minter.testnet"), 0);
  assertEq(nft.totalSupply(), 4);
  assertEq(nft.ownerOf("1"), "bob.testnet");
  assertEq(nft.ownerOf("2"), "alice.testnet");
  assertEq(nft.ownerOf("3"), "carol.testnet");
  assertEq(nft.ownerOf("4"), "bob.testnet");
}
