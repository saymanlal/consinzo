import { near, assertEq, assertThrows } from "near-sdk-js";
import { RoleRegistry, ADMIN_ROLE } from "../../src/RoleRegistry";

function caller(who: string): void {
  near._setContext({ predecessorAccountId: who, signerAccountId: who, attachedDeposit: 0n });
}

export function testHiddenIdempotentGrantAndRevoke(): void {
  caller("root.testnet");
  const reg = new RoleRegistry();
  assertEq(reg.grantRole("minter", "alice.testnet"), true);
  assertEq(reg.grantRole("minter", "alice.testnet"), false);
  assertEq(reg.getRoleMemberCount("minter"), 1);
  assertEq(reg.revokeRole("minter", "bob.testnet"), false);
  assertEq(reg.revokeRole("minter", "alice.testnet"), true);
  assertEq(reg.revokeRole("minter", "alice.testnet"), false);
  assertEq(reg.getRoleMemberCount("minter"), 0);
  assertEq(reg.grantRole(ADMIN_ROLE, "root.testnet"), false);
  assertEq(reg.getRoleMemberCount(ADMIN_ROLE), 1);
}

export function testHiddenSwapAndPopOrder(): void {
  caller("root.testnet");
  const reg = new RoleRegistry();
  for (const who of ["a.testnet", "b.testnet", "c.testnet", "d.testnet"]) {
    reg.grantRole("op", who);
  }
  reg.revokeRole("op", "b.testnet");
  assertEq(reg.getRoleMemberCount("op"), 3);
  assertEq(reg.getRoleMember("op", 0), "a.testnet");
  assertEq(reg.getRoleMember("op", 1), "d.testnet");
  assertEq(reg.getRoleMember("op", 2), "c.testnet");

  // Remove the member that was just moved: its stored position must have been updated.
  reg.revokeRole("op", "d.testnet");
  assertEq(reg.getRoleMember("op", 0), "a.testnet");
  assertEq(reg.getRoleMember("op", 1), "c.testnet");
  assertEq(reg.hasRole("op", "d.testnet"), false);
  assertEq(reg.hasRole("op", "c.testnet"), true);

  // Remove the tail, then the head.
  reg.revokeRole("op", "c.testnet");
  reg.revokeRole("op", "a.testnet");
  assertEq(reg.getRoleMemberCount("op"), 0);
  assertThrows(() => reg.getRoleMember("op", 0), "Index out of bounds");

  assertEq(reg.grantRole("op", "b.testnet"), true);
  assertEq(reg.getRoleMember("op", 0), "b.testnet");
}

export function testHiddenDelegatedRoleAdmin(): void {
  caller("root.testnet");
  const reg = new RoleRegistry();
  reg.grantRole("minter-admin", "carol.testnet");
  reg.setRoleAdmin("minter", "minter-admin");
  assertEq(reg.getRoleAdmin("minter"), "minter-admin");

  // The root admin no longer administers "minter" directly.
  assertThrows(() => reg.grantRole("minter", "alice.testnet"), "Missing role");
  assertThrows(() => reg.setRoleAdmin("minter", ADMIN_ROLE), "Missing role");

  caller("carol.testnet");
  assertEq(reg.grantRole("minter", "alice.testnet"), true);
  assertEq(reg.revokeRole("minter", "alice.testnet"), true);
  assertThrows(() => reg.grantRole("pauser", "alice.testnet"), "Missing role");
  assertThrows(() => reg.setRoleAdmin("pauser", "minter-admin"), "Missing role");

  // Carol can hand administration back.
  reg.setRoleAdmin("minter", ADMIN_ROLE);
  assertThrows(() => reg.grantRole("minter", "alice.testnet"), "Missing role");
  caller("root.testnet");
  assertEq(reg.grantRole("minter", "alice.testnet"), true);
}

export function testHiddenLastAdminRule(): void {
  caller("root.testnet");
  const reg = new RoleRegistry();
  assertThrows(() => reg.revokeRole(ADMIN_ROLE, "root.testnet"), "Last admin");
  assertEq(reg.getRoleMemberCount(ADMIN_ROLE), 1);
  assertEq(reg.getRoleMember(ADMIN_ROLE, 0), "root.testnet");

  reg.grantRole(ADMIN_ROLE, "second.testnet");
  reg.renounceRole(ADMIN_ROLE);
  assertEq(reg.hasRole(ADMIN_ROLE, "root.testnet"), false);
  assertThrows(() => reg.grantRole("minter", "root.testnet"), "Missing role");

  caller("second.testnet");
  assertThrows(() => reg.renounceRole(ADMIN_ROLE), "Last admin");
  assertThrows(() => reg.revokeRole(ADMIN_ROLE, "second.testnet"), "Last admin");
  assertEq(reg.hasRole(ADMIN_ROLE, "second.testnet"), true);

  // The rule only protects ADMIN_ROLE.
  reg.grantRole("minter", "second.testnet");
  reg.renounceRole("minter");
  assertEq(reg.getRoleMemberCount("minter"), 0);
}

export function testHiddenPaginationAndValidation(): void {
  caller("root.testnet");
  const reg = new RoleRegistry();
  const names = ["a.testnet", "b.testnet", "c.testnet", "d.testnet", "e.testnet"];
  for (const who of names) reg.grantRole("op", who);

  const page = reg.getRoleMembers("op", 1, 2);
  assertEq(page.length, 2);
  assertEq(page[0], "b.testnet");
  assertEq(page[1], "c.testnet");
  const tail = reg.getRoleMembers("op", 3, 10);
  assertEq(tail.length, 2);
  assertEq(tail[1], "e.testnet");
  assertEq(reg.getRoleMembers("op", 5, 3).length, 0);
  assertEq(reg.getRoleMembers("op", 0, 0).length, 0);
  assertEq(reg.getRoleMembers("unknown", 0, 5).length, 0);

  assertThrows(() => reg.getRoleMember("op", 5), "Index out of bounds");
  assertThrows(() => reg.getRoleMember("op", -1), "Index out of bounds");
  assertThrows(() => reg.grantRole("", "a.testnet"), "Invalid role");
  assertThrows(() => reg.grantRole("op", ""), "Invalid account");
  assertThrows(() => reg.setRoleAdmin("op", ""), "Invalid role");

  // Roles with similar names stay separate.
  assertEq(reg.hasRole("o", "a.testnet"), false);
  assertEq(reg.getRoleMemberCount("op2"), 0);
}
