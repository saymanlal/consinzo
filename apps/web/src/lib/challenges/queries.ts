import fs from "node:fs";
import path from "node:path";
import YAML from "yaml";
import type { ChallengeManifest } from "@consinzo/challenge-spec";
import { normalizeRepoPath } from "./normalization";
import type { ChallengeFileEntry } from "./types";
import { parseAndValidateManifest, validateLoadedChallengeAssets } from "./validation";

function findChallengesDirectory(): string | null {
  const candidates = [
    path.join(process.cwd(), "content", "challenges"),
    path.resolve(process.cwd(), "..", "..", "content", "challenges"),
    path.resolve(process.cwd(), "..", "content", "challenges"),
    // Bundled relative to compiled Next.js module path when outputFileTracingRoot is monorepo root
    path.resolve(__dirname, "..", "..", "..", "..", "..", "content", "challenges"),
    path.resolve(__dirname, "..", "..", "..", "..", "content", "challenges"),
  ];

  for (const candidate of candidates) {
    try {
      if (fs.existsSync(candidate) && fs.statSync(candidate).isDirectory()) {
        return candidate;
      }
    } catch {
      // continue checking other candidates
    }
  }
  return null;
}

export function getChallengesRootOrThrow(): string {
  const dir = findChallengesDirectory();
  if (!dir) {
    throw new Error(
      "Challenge repository directory (content/challenges) is unavailable in this runtime environment."
    );
  }
  return dir;
}

export function readDirectoryFiles(
  dir: string,
  mountPrefix: string
): Array<{ path: string; content: string }> {
  if (!fs.existsSync(dir)) return [];
  const out: Array<{ path: string; content: string }> = [];
  const walk = (cur: string) => {
    for (const entry of fs.readdirSync(cur, { withFileTypes: true })) {
      const abs = path.join(cur, entry.name);
      if (entry.isDirectory()) {
        walk(abs);
      } else {
        const rel = normalizeRepoPath(path.relative(dir, abs));
        out.push({
          path: `${mountPrefix}${rel}`,
          content: fs.readFileSync(abs, "utf8"),
        });
      }
    }
  };
  walk(dir);
  return out.sort((a, b) => a.path.localeCompare(b.path));
}

export function loadAllManifestsFromDisk(): {
  manifests: ChallengeManifest[];
  duplicates: string[];
} {
  const root = getChallengesRootOrThrow();
  const manifests: ChallengeManifest[] = [];
  const seenSlugs = new Set<string>();
  const duplicates: string[] = [];

  for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const manifestPath = path.join(root, entry.name, "challenge.yaml");
    if (!fs.existsSync(manifestPath)) continue;

    const raw = YAML.parse(fs.readFileSync(manifestPath, "utf8"));
    const { manifest } = parseAndValidateManifest(raw);
    if (!manifest) continue;

    if (seenSlugs.has(manifest.slug)) {
      duplicates.push(manifest.slug);
      continue;
    }
    seenSlugs.add(manifest.slug);
    manifests.push(manifest);
  }

  return { manifests, duplicates };
}

export function loadSingleChallengePackage(slug: string): {
  exists: boolean;
  manifest?: ChallengeManifest;
  readmeMarkdown?: string;
  starterFiles?: ChallengeFileEntry[];
  publicTests?: Array<{ path: string; content: string }>;
  hasHiddenTests?: boolean;
  integrityErrors?: string[];
} {
  const root = getChallengesRootOrThrow();
  const dir = path.join(root, slug);
  const manifestPath = path.join(dir, "challenge.yaml");
  if (!fs.existsSync(manifestPath)) {
    return { exists: false };
  }

  const raw = YAML.parse(fs.readFileSync(manifestPath, "utf8"));
  const { manifest, errors } = parseAndValidateManifest(raw);
  if (!manifest) {
    return { exists: true, integrityErrors: errors };
  }

  const readmePath = path.join(dir, "README.md");
  const readmeMarkdown = fs.existsSync(readmePath) ? fs.readFileSync(readmePath, "utf8") : "";

  const readonlySet = new Set(manifest.starter.readonly_files.map(normalizeRepoPath));
  const starterSrc = readDirectoryFiles(path.join(dir, "starter", "src"), "src/").map((f) => ({
    ...f,
    readOnly: readonlySet.has(f.path),
  }));
  const starterTest = readDirectoryFiles(path.join(dir, "starter", "test"), "test/").map((f) => ({
    ...f,
    readOnly: readonlySet.has(f.path),
  }));
  const starterFiles = [...starterSrc, ...starterTest];
  const publicTests = readDirectoryFiles(path.join(dir, "evaluation", "public"), "test/");

  const integrity = validateLoadedChallengeAssets(manifest, starterFiles, publicTests);

  const hiddenDir = path.join(dir, "evaluation", "hidden");
  const hasHiddenTests =
    Boolean(manifest.tests.hidden_suite) &&
    ((fs.existsSync(hiddenDir) && fs.readdirSync(hiddenDir).length > 0) ||
      Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY));

  return {
    exists: true,
    manifest,
    readmeMarkdown,
    starterFiles,
    publicTests,
    hasHiddenTests,
    integrityErrors: integrity.valid ? undefined : integrity.errors,
  };
}
