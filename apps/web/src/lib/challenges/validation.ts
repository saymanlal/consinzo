import { ChallengeManifestSchema, type ChallengeManifest } from "@consinzo/challenge-spec";
import { getEcosystemById } from "@consinzo/ecosystem-registry";
import type { ChallengeFileEntry } from "./types";

export interface ChallengeIntegrityCheck {
  valid: boolean;
  errors: string[];
}

export function parseAndValidateManifest(raw: unknown): {
  manifest?: ChallengeManifest;
  errors: string[];
} {
  const parsed = ChallengeManifestSchema.safeParse(raw);
  if (!parsed.success) {
    return {
      errors: parsed.error.issues.map((i) => `${i.path.join(".")}: ${i.message}`),
    };
  }
  const manifest = parsed.data;
  const errors: string[] = [];

  if (!getEcosystemById(manifest.ecosystem)) {
    errors.push(`Unknown ecosystem "${manifest.ecosystem}"`);
  }
  if (!manifest.id || !manifest.slug) {
    errors.push("Missing challenge id or slug");
  }

  return errors.length > 0 ? { errors } : { manifest, errors: [] };
}

export function validateLoadedChallengeAssets(
  manifest: ChallengeManifest,
  starterFiles: ChallengeFileEntry[],
  publicTests: Array<{ path: string; content: string }>
): ChallengeIntegrityCheck {
  const errors: string[] = [];
  if (starterFiles.length === 0) {
    errors.push(`No starter files found for challenge "${manifest.slug}".`);
  }
  if (!starterFiles.some((f) => f.path === manifest.starter.entry_file)) {
    errors.push(`Missing starter entry file "${manifest.starter.entry_file}".`);
  }
  if (publicTests.length === 0) {
    errors.push(`No public test suite files found for challenge "${manifest.slug}".`);
  }
  return { valid: errors.length === 0, errors };
}
