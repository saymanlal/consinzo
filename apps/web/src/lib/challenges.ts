import fs from "node:fs";
import path from "node:path";
import YAML from "yaml";
import {
  ChallengeManifestSchema,
  type ChallengeManifest,
  type PublicChallengeView,
} from "@consinzo/challenge-spec";
import type { ProjectFile } from "@consinzo/shared";

function resolveMonorepoRoot(): string {
  const candidates = [
    process.cwd(),
    path.resolve(process.cwd(), "../.."),
    path.resolve(process.cwd(), ".."),
  ];
  for (const c of candidates) {
    if (fs.existsSync(path.join(c, "content", "challenges"))) {
      return c;
    }
  }
  return process.cwd();
}

export function getChallengesRoot(): string {
  return path.join(resolveMonorepoRoot(), "content", "challenges");
}

function readFilesInDir(dir: string, mountPrefix: string): Array<{ path: string; content: string }> {
  if (!fs.existsSync(dir)) return [];
  const out: Array<{ path: string; content: string }> = [];
  const walk = (cur: string) => {
    for (const entry of fs.readdirSync(cur, { withFileTypes: true })) {
      const abs = path.join(cur, entry.name);
      if (entry.isDirectory()) {
        walk(abs);
      } else {
        const rel = path.relative(dir, abs).replaceAll("\\", "/");
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

export function listPublishedChallenges(): ChallengeManifest[] {
  const root = getChallengesRoot();
  if (!fs.existsSync(root)) return [];

  const manifests: ChallengeManifest[] = [];
  for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const manifestPath = path.join(root, entry.name, "challenge.yaml");
    if (!fs.existsSync(manifestPath)) continue;
    try {
      const parsed = ChallengeManifestSchema.safeParse(
        YAML.parse(fs.readFileSync(manifestPath, "utf8"))
      );
      if (parsed.success && parsed.data.publication_status === "published") {
        manifests.push(parsed.data);
      }
    } catch {
      // Skip malformed manifest
    }
  }

  return manifests.sort((a, b) => a.title.localeCompare(b.title));
}

export function getPublicChallengeBySlug(slug: string): PublicChallengeView | null {
  if (!/^[a-z0-9-]+$/.test(slug)) return null;
  const dir = path.join(getChallengesRoot(), slug);
  const manifestPath = path.join(dir, "challenge.yaml");
  if (!fs.existsSync(manifestPath)) return null;

  const parsed = ChallengeManifestSchema.safeParse(
    YAML.parse(fs.readFileSync(manifestPath, "utf8"))
  );
  if (!parsed.success || parsed.data.publication_status !== "published") return null;
  const manifest = parsed.data;

  const readmePath = path.join(dir, "README.md");
  const readmeMarkdown = fs.existsSync(readmePath) ? fs.readFileSync(readmePath, "utf8") : "";

  const readonlySet = new Set(manifest.starter.readonly_files);
  const starterSrc = readFilesInDir(path.join(dir, "starter", "src"), "src/").map((f) => ({
    ...f,
    readOnly: readonlySet.has(f.path),
  }));
  const starterTest = readFilesInDir(path.join(dir, "starter", "test"), "test/").map((f) => ({
    ...f,
    readOnly: readonlySet.has(f.path),
  }));
  const publicTests = readFilesInDir(path.join(dir, "evaluation", "public"), "test/");

  const hiddenDir = path.join(dir, "evaluation", "hidden");
  const hasHiddenTests =
    Boolean(manifest.tests.hidden_suite) &&
    fs.existsSync(hiddenDir) &&
    fs.readdirSync(hiddenDir).length > 0;

  return {
    manifest,
    readmeMarkdown,
    starterFiles: [...starterSrc, ...starterTest],
    publicTests,
    hasHiddenTests,
  };
}

/**
 * SERVER-ONLY: Reads private hidden test files for server-side evaluation.
 * Never expose return values from this function directly to browser APIs.
 */
export function getServerHiddenTestFiles(slug: string): ProjectFile[] {
  if (!/^[a-z0-9-]+$/.test(slug)) return [];
  const dir = path.join(getChallengesRoot(), slug, "evaluation", "hidden");
  return readFilesInDir(dir, "evaluation/hidden/");
}

/**
 * SERVER-ONLY: Reads reference solution & explanation.
 * Must only be returned after verifying challenge_unlocks or admin role.
 */
export function getServerReferenceSolution(slug: string): {
  files: Array<{ path: string; content: string }>;
  explanationMarkdown: string;
} | null {
  if (!/^[a-z0-9-]+$/.test(slug)) return null;
  const dir = path.join(getChallengesRoot(), slug);
  const refDir = path.join(dir, "solution", "reference");
  if (!fs.existsSync(refDir)) return null;
  const expPath = path.join(dir, "solution", "explanation.md");
  return {
    files: readFilesInDir(refDir, "src/"),
    explanationMarkdown: fs.existsSync(expPath) ? fs.readFileSync(expPath, "utf8") : "",
  };
}
