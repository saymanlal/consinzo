import { describe, expect, it } from "vitest";
import { ACHIEVEMENT_CATALOG } from "./achievements";
import {
  buildCaption,
  buildShareTitle,
  CAPTION_TONES,
  SHARE_PLATFORMS,
  type ShareSubject,
} from "./share";

const url = "https://consinzo.example/u/sol_architect?badge=defi-protocol-builder";
const base: ShareSubject = {
  displayName: "Alex Rivera",
  username: "sol_architect",
  totalPoints: 1850,
  challengesCompleted: 12,
  securityMissionsCompleted: 5,
  badgeCount: 4,
};

describe("Share captions", () => {
  it("stay inside every network's length budget, link included, for every badge and tone", () => {
    const subjects: ShareSubject[] = [
      base,
      { ...base, totalPoints: 0, challengesCompleted: 0, securityMissionsCompleted: 0, badgeCount: 0 },
      ...Object.values(ACHIEVEMENT_CATALOG).map((m) => ({
        ...base,
        badge: { title: m.title, feat: m.feat, track: m.track },
      })),
    ];
    for (const subject of subjects) {
      for (const platform of SHARE_PLATFORMS) {
        for (const tone of CAPTION_TONES) {
          const caption = buildCaption(subject, platform.id, tone.id, url);
          const linkCost = platform.id === "x" ? 23 : url.length;
          expect(caption.length + linkCost + 1, `${platform.id}/${tone.id}`).toBeLessThanOrEqual(
            platform.limit
          );
          expect(caption.trim().length).toBeGreaterThan(10);
          expect(caption).not.toMatch(/undefined|NaN|\[object/);
        }
      }
    }
  });

  it("only states numbers the profile has, and never invents activity for a new account", () => {
    const fresh = { ...base, totalPoints: 0, challengesCompleted: 0, securityMissionsCompleted: 0, badgeCount: 0 };
    for (const tone of CAPTION_TONES) {
      const caption = buildCaption(fresh, "linkedin", tone.id, url);
      expect(caption).not.toMatch(/\d+ (challenge|security mission|verified point)/);
    }
    const caption = buildCaption(base, "linkedin", "technical", url);
    expect(caption).toContain("12 challenges passed");
    expect(caption).toContain("5 security missions cleared");
    expect(caption).toContain("1,850 verified points");
  });

  it("uses hashtags only where they are idiomatic and builds valid composer links", () => {
    expect(buildCaption(base, "x", "proud", url)).toContain("#web3");
    expect(buildCaption(base, "farcaster", "proud", url)).not.toContain("#");
    for (const platform of SHARE_PLATFORMS) {
      const link = platform.compose("Hello & goodbye #1", url, buildShareTitle(base));
      expect(() => new URL(link)).not.toThrow();
      expect(link.startsWith("https://")).toBe(true);
      expect(link).toContain(encodeURIComponent("sol_architect"));
    }
  });
});
