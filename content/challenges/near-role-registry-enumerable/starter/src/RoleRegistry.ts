import { LookupMap, near, assert } from "near-sdk-js";

export const ADMIN_ROLE = "admin";

export class RoleRegistry {
  // role -> ordered member list
  private members = new LookupMap<string[]>("m:");
  // (role, account) -> position in the member list
  private positions = new LookupMap<number>("i:");
  // role -> admin role (absent means ADMIN_ROLE)
  private roleAdmins = new LookupMap<string>("a:");

  constructor() {
    // TODO: make the deployer the first member of ADMIN_ROLE
  }

  grantRole(role: string, account: string): boolean {
    // TODO: caller must hold the admin role of `role`; return false if already granted
    return false;
  }

  revokeRole(role: string, account: string): boolean {
    // TODO: caller must hold the admin role of `role`; protect the last root admin
    return false;
  }

  renounceRole(role: string): void {
    // TODO: remove the role from the caller; protect the last root admin
  }

  setRoleAdmin(role: string, adminRole: string): void {
    // TODO: caller must hold the current admin role of `role`
  }

  hasRole(role: string, account: string): boolean {
    // TODO
    return false;
  }

  getRoleAdmin(role: string): string {
    // TODO: ADMIN_ROLE unless changed
    return "";
  }

  getRoleMemberCount(role: string): number {
    // TODO
    return 0;
  }

  getRoleMember(role: string, index: number): string {
    // TODO: throw "Index out of bounds" for an invalid index
    return "";
  }

  getRoleMembers(role: string, fromIndex: number, limit: number): string[] {
    // TODO: paginated slice of the member list
    return [];
  }
}
