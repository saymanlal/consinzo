import { LookupMap, near, assert } from "near-sdk-js";

export interface Profile {
  name: string;
  bio: string;
  updatedAt: bigint;
}

export const MAX_NAME_LENGTH = 32;
export const MAX_BIO_LENGTH = 160;

export class ProfileRegistry {
  private profiles = new LookupMap<Profile>("profile:");
  private count = 0;

  setProfile(name: string, bio: string): void {
    assert(name.length >= 1 && name.length <= MAX_NAME_LENGTH, "Invalid name");
    assert(bio.length <= MAX_BIO_LENGTH, "Bio too long");
    const caller = near.predecessorAccountId();
    // Only a brand-new profile changes the count; an update overwrites in place.
    if (!this.profiles.containsKey(caller)) this.count += 1;
    this.profiles.set(caller, { name, bio, updatedAt: near.blockTimestamp() });
  }

  getProfile(account: string): Profile | null {
    return this.profiles.get(account);
  }

  deleteProfile(): void {
    const caller = near.predecessorAccountId();
    assert(this.profiles.containsKey(caller), "Profile not found");
    this.profiles.remove(caller);
    this.count -= 1;
  }

  profileCount(): number {
    return this.count;
  }
}
