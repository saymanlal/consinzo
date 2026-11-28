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
    this.add(ADMIN_ROLE, near.predecessorAccountId());
  }

  grantRole(role: string, account: string): boolean {
    this.checkArgs(role, account);
    this.requireAdminOf(role);
    if (this.hasRole(role, account)) return false;
    this.add(role, account);
    return true;
  }

  revokeRole(role: string, account: string): boolean {
    this.checkArgs(role, account);
    this.requireAdminOf(role);
    if (!this.hasRole(role, account)) return false;
    this.remove(role, account);
    return true;
  }

  renounceRole(role: string): void {
    assert(role.length > 0, "Invalid role");
    const caller = near.predecessorAccountId();
    assert(this.hasRole(role, caller), "Role not held");
    this.remove(role, caller);
  }

  setRoleAdmin(role: string, adminRole: string): void {
    assert(role.length > 0 && adminRole.length > 0, "Invalid role");
    this.requireAdminOf(role);
    this.roleAdmins.set(role, adminRole);
  }

  hasRole(role: string, account: string): boolean {
    return this.positions.containsKey(this.key(role, account));
  }

  getRoleAdmin(role: string): string {
    return this.roleAdmins.get(role) ?? ADMIN_ROLE;
  }

  getRoleMemberCount(role: string): number {
    return (this.members.get(role) ?? []).length;
  }

  getRoleMember(role: string, index: number): string {
    const list = this.members.get(role) ?? [];
    assert(Number.isInteger(index) && index >= 0 && index < list.length, "Index out of bounds");
    return list[index] as string;
  }

  getRoleMembers(role: string, fromIndex: number, limit: number): string[] {
    const list = this.members.get(role) ?? [];
    if (fromIndex < 0 || limit <= 0 || fromIndex >= list.length) return [];
    return list.slice(fromIndex, fromIndex + limit);
  }

  // Length-prefixing the role keeps ("a", "b:c") and ("a:b", "c") apart.
  private key(role: string, account: string): string {
    return `${role.length}:${role}:${account}`;
  }

  private checkArgs(role: string, account: string): void {
    assert(role.length > 0, "Invalid role");
    assert(account.length > 0, "Invalid account");
  }

  private requireAdminOf(role: string): void {
    assert(this.hasRole(this.getRoleAdmin(role), near.predecessorAccountId()), "Missing role");
  }

  private add(role: string, account: string): void {
    const list = this.members.get(role) ?? [];
    this.positions.set(this.key(role, account), list.length);
    list.push(account);
    this.members.set(role, list);
  }

  private remove(role: string, account: string): void {
    const list = this.members.get(role) ?? [];
    // Checked before any write so a rejected call leaves storage untouched.
    assert(!(role === ADMIN_ROLE && list.length === 1), "Last admin");
    const pos = this.positions.get(this.key(role, account)) as number;
    const last = list[list.length - 1] as string;
    if (last !== account) {
      list[pos] = last;
      this.positions.set(this.key(role, last), pos);
    }
    list.pop();
    this.positions.remove(this.key(role, account));
    this.members.set(role, list);
  }
}
