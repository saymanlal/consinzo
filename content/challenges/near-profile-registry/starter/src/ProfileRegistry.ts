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
    // TODO: validate name ("Invalid name") and bio ("Bio too long"), store the profile under the caller, count only first-time creations
    throw new Error("Not implemented");
  }

  getProfile(account: string): Profile | null {
    return this.profiles.get(account);
  }

  deleteProfile(): void {
    // TODO: remove the caller's profile or throw "Profile not found", and keep the count correct
    throw new Error("Not implemented");
  }

  profileCount(): number {
    return this.count;
  }
}
