import path from "node:path";
import fs from "node:fs";
import type { ChallengeManifest, PublicChallengeView } from "@consinzo/challenge-spec";
import type { ProjectFile } from "@consinzo/shared";
import { normalizeSlug } from "./normalization";
import {
  getChallengesRootOrThrow,
  loadAllManifestsFromDisk,
  loadSingleChallengePackage,
  readDirectoryFiles,
} from "./queries";
import type {
  ChallengeListResult,
  ChallengeLoadResult,
  RelatedChallengeSummary,
} from "./types";

export function getPublishedChallengesResult(): ChallengeListResult {
  try {
    const { manifests } = loadAllManifestsFromDisk();
    const published = manifests
      .filter((m) => m.publication_status === "published")
      .sort((a, b) => a.title.localeCompare(b.title));
    return { status: "ok", challenges: published };
  } catch (err) {
    return {
      status: "error",
      kind: "storage_error",
      message: (err as Error).message || "Failed to load challenge repository.",
    };
  }
}

export function getPublishedChallenges(): ChallengeManifest[] {
  const res = getPublishedChallengesResult();
  return res.status === "ok" ? res.challenges : [];
}

export function getChallengeBySlug(rawSlug: string): ChallengeLoadResult {
  const slug = normalizeSlug(rawSlug);
  if (!slug) {
    return {
      status: "error",
      kind: "invalid_slug",
      message: "Invalid or malformed challenge slug.",
      recoverable: false,
    };
  }

  try {
    const pkg = loadSingleChallengePackage(slug);
    if (!pkg.exists) {
      return {
        status: "error",
        kind: "not_found",
        message: `Challenge "${slug}" does not exist.`,
        recoverable: false,
      };
    }

    if (!pkg.manifest) {
      return {
        status: "error",
        kind: "incomplete",
        message: `Challenge "${slug}" manifest is invalid: ${(pkg.integrityErrors ?? []).join("; ")}`,
        recoverable: false,
      };
    }

    if (pkg.manifest.publication_status !== "published") {
      return {
        status: "error",
        kind: "unpublished",
        message: `Challenge "${slug}" is not currently published (${pkg.manifest.publication_status}).`,
        recoverable: false,
      };
    }

    if (pkg.integrityErrors && pkg.integrityErrors.length > 0) {
      return {
        status: "error",
        kind: "incomplete",
        message: `Challenge "${slug}" starter assets are incomplete: ${pkg.integrityErrors.join("; ")}`,
        recoverable: false,
      };
    }

    return {
      status: "ok",
      data: {
        manifest: pkg.manifest,
        readmeMarkdown: pkg.readmeMarkdown ?? "",
        starterFiles: pkg.starterFiles ?? [],
        publicTests: pkg.publicTests ?? [],
        hasHiddenTests: Boolean(pkg.hasHiddenTests),
      },
    };
  } catch (err) {
    return {
      status: "error",
      kind: "storage_error",
      message: (err as Error).message || "Failed to read challenge package from storage.",
      recoverable: true,
    };
  }
}

export function getChallengeById(id: string): ChallengeLoadResult {
  const all = getPublishedChallengesResult();
  if (all.status === "error") {
    return {
      status: "error",
      kind: "storage_error",
      message: all.message,
      recoverable: true,
    };
  }
  const match = all.challenges.find((c) => c.id === id);
  if (!match) {
    return {
      status: "error",
      kind: "not_found",
      message: `Challenge id "${id}" not found.`,
      recoverable: false,
    };
  }
  return getChallengeBySlug(match.slug);
}

export function getChallengesByEcosystem(ecosystem: string): ChallengeManifest[] {
  return getPublishedChallenges().filter((c) => c.ecosystem === ecosystem);
}

export function getChallengesByDifficulty(difficulty: string): ChallengeManifest[] {
  return getPublishedChallenges().filter((c) => c.difficulty === difficulty);
}

export function searchChallenges(query: string): ChallengeManifest[] {
  const q = query.trim().toLowerCase();
  if (!q) return getPublishedChallenges();
  return getPublishedChallenges().filter(
    (c) =>
      c.slug.toLowerCase().includes(q) ||
      c.title.toLowerCase().includes(q) ||
      c.description.toLowerCase().includes(q) ||
      c.tags.some((t) => t.toLowerCase().includes(q)) ||
      c.category.toLowerCase().includes(q)
  );
}

export function getRelatedChallenges(challengeId: string, limit = 3): RelatedChallengeSummary[] {
  const all = getPublishedChallenges();
  const target = all.find((c) => c.id === challengeId);
  if (!target) return [];

  return all
    .filter((c) => c.id !== challengeId)
    .map((c) => {
      let score = 0;
      if (c.category === target.category) score += 3;
      if (c.ecosystem === target.ecosystem) score += 2;
      if (c.difficulty === target.difficulty) score += 1;
      for (const t of c.tags) {
        if (target.tags.includes(t)) score += 1;
      }
      return { item: c, score };
    })
    .sort((a, b) => b.score - a.score || a.item.title.localeCompare(b.item.title))
    .slice(0, limit)
    .map(({ item }) => ({
      id: item.id,
      slug: item.slug,
      title: item.title,
      ecosystem: item.ecosystem,
      difficulty: item.difficulty,
      category: item.category,
      maxPoints: item.scoring.max_points,
    }));
}

export function getAdjacentChallenges(slug: string): {
  previous: RelatedChallengeSummary | null;
  next: RelatedChallengeSummary | null;
} {
  const all = getPublishedChallenges();
  const idx = all.findIndex((c) => c.slug === slug);
  if (idx === -1) return { previous: null, next: null };

  const toSummary = (c: ChallengeManifest): RelatedChallengeSummary => ({
    id: c.id,
    slug: c.slug,
    title: c.title,
    ecosystem: c.ecosystem,
    difficulty: c.difficulty,
    category: c.category,
    maxPoints: c.scoring.max_points,
  });

  return {
    previous: idx > 0 ? toSummary(all[idx - 1]!) : null,
    next: idx < all.length - 1 ? toSummary(all[idx + 1]!) : null,
  };
}

// Backwards-compatible aliases
export const listPublishedChallenges = getPublishedChallenges;

export function getPublicChallengeBySlug(slug: string): PublicChallengeView | null {
  const res = getChallengeBySlug(slug);
  return res.status === "ok" ? res.data : null;
}

/**
 * SERVER-ONLY: Reads private hidden test files for server-side evaluation.
 * Never expose return values from this function directly to browser APIs.
 */
export function getServerHiddenTestFiles(rawSlug: string): ProjectFile[] {
  const slug = normalizeSlug(rawSlug);
  if (!slug) return [];
  try {
    const dir = path.join(getChallengesRootOrThrow(), slug, "evaluation", "hidden");
    return readDirectoryFiles(dir, "evaluation/hidden/");
  } catch {
    return [];
  }
}

/**
 * SERVER-ONLY: Reads reference solution & explanation.
 * Must only be returned after verifying challenge_unlocks or admin role.
 */
export function getServerReferenceSolution(rawSlug: string): {
  files: Array<{ path: string; content: string }>;
  explanationMarkdown: string;
} | null {
  const slug = normalizeSlug(rawSlug);
  if (!slug) return null;
  try {
    const dir = path.join(getChallengesRootOrThrow(), slug);
    const refDir = path.join(dir, "solution", "reference");
    if (!fs.existsSync(refDir)) return null;
    const expPath = path.join(dir, "solution", "explanation.md");
    return {
      files: readDirectoryFiles(refDir, "src/"),
      explanationMarkdown: fs.existsSync(expPath) ? fs.readFileSync(expPath, "utf8") : "",
    };
  } catch {
    return null;
  }
}
