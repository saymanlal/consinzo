import fs from "node:fs";
import path from "node:path";
import YAML from "yaml";
import { z } from "zod";
import { ChallengeManifestSchema, type ChallengeManifest } from "@consinzo/challenge-spec";
import { ConsinzoError, FREE_TIER_LIMITS, type ProjectFile } from "@consinzo/shared";

export interface ChallengeValidationResult {
  valid: boolean;
  challengeId?: string;
  manifest?: ChallengeManifest;
  errors: string[];
  warnings: string[];
}

const SAFE_RELATIVE_PATH = /^[a-zA-Z0-9._-]+(\/[a-zA-Z0-9._-]+)*$/;

export const SnapshotSubmissionSchema = z.object({
  challengeSlug: z.string().regex(/^[a-z0-9-]+$/),
  mode: z.enum(["browser-worker", "local-cli", "remote-actions"]).default("local-cli"),
  files: z
    .array(
      z.object({
        path: z.string().min(1).max(180),
        content: z.string(),
      })
    )
    .min(1)
    .max(FREE_TIER_LIMITS.MAX_FILES_PER_SNAPSHOT),
});

export function validateProjectSnapshot(files: ProjectFile[]): {
  totalBytes: number;
  sanitizedFiles: ProjectFile[];
} {
  let totalBytes = 0;
  const seen = new Set<string>();
  const sanitizedFiles: ProjectFile[] = [];

  for (const f of files) {
    const normalized = f.path.replaceAll("\\", "/").replace(/^\.\//, "");
    if (
      normalized.includes("..") ||
      normalized.startsWith("/") ||
      normalized.includes("\0") ||
      !SAFE_RELATIVE_PATH.test(normalized)
    ) {
      throw new ConsinzoError(
        "INVALID_FILE_PATH",
        `Unsafe or invalid project file path: ${f.path}`,
        400
      );
    }
    if (normalized.startsWith("evaluation/hidden") || normalized.startsWith("solution/")) {
      throw new ConsinzoError(
        "FORBIDDEN_PATH",
        `Submissions cannot overwrite protected path: ${normalized}`,
        403
      );
    }
    if (seen.has(normalized)) {
      throw new ConsinzoError("DUPLICATE_FILE_PATH", `Duplicate file path: ${normalized}`, 400);
    }
    seen.add(normalized);

    const bytes = Buffer.byteLength(f.content, "utf8");
    totalBytes += bytes;
    if (totalBytes > FREE_TIER_LIMITS.MAX_PROJECT_BYTES) {
      throw new ConsinzoError(
        "PROJECT_SIZE_EXCEEDED",
        `Project snapshot exceeds free-tier cap of ${FREE_TIER_LIMITS.MAX_PROJECT_BYTES} bytes`,
        413
      );
    }

    sanitizedFiles.push({ path: normalized, content: f.content, readOnly: f.readOnly });
  }

  return { totalBytes, sanitizedFiles };
}

export function validateChallengeDirectory(challengeDir: string): ChallengeValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  const manifestPath = path.join(challengeDir, "challenge.yaml");
  if (!fs.existsSync(manifestPath)) {
    return { valid: false, errors: [`Missing challenge.yaml in ${challengeDir}`], warnings };
  }

  let parsedRaw: unknown;
  try {
    const yamlText = fs.readFileSync(manifestPath, "utf8");
    parsedRaw = YAML.parse(yamlText);
  } catch (err) {
    return {
      valid: false,
      errors: [`Failed to parse challenge.yaml: ${(err as Error).message}`],
      warnings,
    };
  }

  const parsed = ChallengeManifestSchema.safeParse(parsedRaw);
  if (!parsed.success) {
    for (const issue of parsed.error.issues) {
      errors.push(`Manifest error at ${issue.path.join(".")}: ${issue.message}`);
    }
    return { valid: false, errors, warnings };
  }

  const manifest = parsed.data;
  const requiredFiles = [
    "README.md",
    "LICENSE",
    path.join("starter", manifest.starter.entry_file),
    manifest.tests.public_suite,
    "solution/explanation.md",
    "resources/documentation.md",
  ];

  for (const rel of requiredFiles) {
    const abs = path.join(challengeDir, rel);
    if (!fs.existsSync(abs)) {
      errors.push(`Missing required file: ${rel}`);
    }
  }

  for (const editable of manifest.starter.editable_files) {
    const abs = path.join(challengeDir, "starter", editable);
    if (!fs.existsSync(abs)) {
      errors.push(`Declared starter.editable_file missing: starter/${editable}`);
    }
  }

  const solRefDir = path.join(challengeDir, "solution", "reference");
  if (!fs.existsSync(solRefDir) || fs.readdirSync(solRefDir).length === 0) {
    errors.push("Missing reference solution files in solution/reference/");
  }

  if (manifest.tests.hidden_suite) {
    const hiddenPath = path.join(challengeDir, manifest.tests.hidden_suite);
    if (!fs.existsSync(hiddenPath)) {
      errors.push(`Declared hidden_suite missing: ${manifest.tests.hidden_suite}`);
    }
  } else {
    warnings.push("No hidden_suite declared; only public tests will be evaluated.");
  }

  // Ensure starter/ does not accidentally leak hidden tests or solutions
  const starterDir = path.join(challengeDir, "starter");
  if (fs.existsSync(starterDir)) {
    const walk = (dir: string) => {
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) {
          if (entry.name === "hidden" || entry.name === "solution") {
            errors.push(`Forbidden directory inside starter/: ${full}`);
          }
          walk(full);
        } else {
          const content = fs.readFileSync(full, "utf8");
          if (/PRIVATE_KEY|SECRET_KEY|SUPABASE_SERVICE_ROLE/i.test(content)) {
            errors.push(`Potential secret token detected in starter file: ${full}`);
          }
        }
      }
    };
    walk(starterDir);
  }

  return {
    valid: errors.length === 0,
    challengeId: manifest.id,
    manifest,
    errors,
    warnings,
  };
}

export const AuditFindingInputSchema = z.object({
  missionSlug: z.string().regex(/^[a-z0-9-]+$/),
  title: z.string().min(6).max(160),
  severity: z.enum(["critical", "high", "medium", "low", "informational"]),
  affectedComponent: z.string().min(2).max(160),
  rootCause: z.string().min(20).max(4000),
  attackScenario: z.string().min(20).max(4000),
  impact: z.string().min(15).max(2000),
  proofOfConcept: z.string().min(15).max(12000),
  recommendedRemediation: z.string().min(20).max(4000),
});
