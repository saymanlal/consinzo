import { near, assertEq, assertThrows } from "near-sdk-js";
import { RoleRegistry, ADMIN_ROLE } from "../src/RoleRegistry";

function caller(who: string): void {
  near._setContext({ predecessorAccountId: who, signerAccountId: who, attachedDeposit: 0n });
}

export function testDeployerIsAdminAndCanGrant(): void {
  caller("root.testnet");
  const reg = new RoleRegistry();
  assertEq(reg.hasRole(ADMIN_ROLE, "root.testnet"), true);
  assertEq(reg.getRoleAdmin("minter"), ADMIN_ROLE);

  assertEq(reg.grantRole("minter", "alice.testnet"), true);
  assertEq(reg.grantRole("minter", "bob.testnet"), true);
  assertEq(reg.hasRole("minter", "alice.testnet"), true);
  assertEq(reg.hasRole("minter", "carol.testnet"), false);
  assertEq(reg.getRoleMemberCount("minter"), 2);
  assertEq(reg.getRoleMember("minter", 0), "alice.testnet");
  assertEq(reg.getRoleMember("minter", 1), "bob.testnet");
}

export function testOutsiderCannotGrantOrRevoke(): void {
  caller("root.testnet");
  const reg = new RoleRegistry();
  reg.grantRole("minter", "alice.testnet");

  caller("mallory.testnet");
  assertThrows(() => reg.grantRole("minter", "mallory.testnet"), "Missing role");
  assertThrows(() => reg.revokeRole("minter", "alice.testnet"), "Missing role");
  assertThrows(() => reg.grantRole(ADMIN_ROLE, "mallory.testnet"), "Missing role");

  // Holding a role does not make you its admin.
  caller("alice.testnet");
  assertThrows(() => reg.grantRole("minter", "bob.testnet"), "Missing role");
  assertEq(reg.getRoleMemberCount("minter"), 1);
}

export function testRevokeAndRenounce(): void {
  caller("root.testnet");
  const reg = new RoleRegistry();
  reg.grantRole("pauser", "alice.testnet");
  reg.grantRole("pauser", "bob.testnet");

  assertEq(reg.revokeRole("pauser", "alice.testnet"), true);
  assertEq(reg.hasRole("pauser", "alice.testnet"), false);
  assertEq(reg.getRoleMemberCount("pauser"), 1);
  assertEq(reg.getRoleMember("pauser", 0), "bob.testnet");

  caller("bob.testnet");
  reg.renounceRole("pauser");
  assertEq(reg.getRoleMemberCount("pauser"), 0);
  assertThrows(() => reg.renounceRole("pauser"), "Role not held");
}

export function testLastAdminCannotLeave(): void {
  caller("root.testnet");
  const reg = new RoleRegistry();
  assertThrows(() => reg.renounceRole(ADMIN_ROLE), "Last admin");
  assertEq(reg.hasRole(ADMIN_ROLE, "root.testnet"), true);
}
