import fs from "node:fs";
import path from "node:path";
import type { ProjectFile } from "@consinzo/shared";
import { getSupabaseAdminClient } from "../supabase";
import { normalizeSlug } from "./normalization";
import { getChallengesRootOrThrow, readDirectoryFiles } from "./queries";

const PRIVATE_BUCKET = process.env.CONSINZO_PRIVATE_BUCKET || "consinzo-private";

async function downloadBucketFolder(
  prefix: string,
  mountPrefix: string
): Promise<Array<{ path: string; content: string }> | null> {
  const supabase = getSupabaseAdminClient();
  if (!supabase) return null;

  try {
    const { data: entries, error } = await supabase.storage
      .from(PRIVATE_BUCKET)
      .list(prefix, { limit: 100 });
    if (error || !entries || entries.length === 0) {
      return null;
    }

    const files: Array<{ path: string; content: string }> = [];
    for (const entry of entries) {
      if (!entry.name || entry.id === null) continue; // skip folder placeholders
      const objectPath = `${prefix}/${entry.name}`;
      const { data: blob, error: dlErr } = await supabase.storage
        .from(PRIVATE_BUCKET)
        .download(objectPath);
      if (dlErr || !blob) continue;
      files.push({
        path: `${mountPrefix}${entry.name}`,
        content: await blob.text(),
      });
    }
    return files.length > 0 ? files.sort((a, b) => a.path.localeCompare(b.path)) : null;
  } catch {
    return null;
  }
}

/**
 * SERVER-ONLY: Loads private hidden evaluation tests.
 * Priority:
 *   1. Private Supabase Storage bucket (`consinzo-private/challenges/<slug>/evaluation/hidden`)
 *   2. Local filesystem (`content/challenges/<slug>/evaluation/hidden`)
 */
export async function loadPrivateHiddenTestFiles(rawSlug: string): Promise<ProjectFile[]> {
  const slug = normalizeSlug(rawSlug);
  if (!slug) return [];

  const remote = await downloadBucketFolder(
    `challenges/${slug}/evaluation/hidden`,
    "evaluation/hidden/"
  );
  if (remote && remote.length > 0) {
    return remote;
  }

  try {
    const dir = path.join(getChallengesRootOrThrow(), slug, "evaluation", "hidden");
    return readDirectoryFiles(dir, "evaluation/hidden/");
  } catch {
    return [];
  }
}

/**
 * SERVER-ONLY: Loads protected reference solution & explanation.
 * Priority:
 *   1. Private Supabase Storage bucket (`consinzo-private/challenges/<slug>/solution`)
 *   2. Local filesystem (`content/challenges/<slug>/solution`)
 */
export async function loadPrivateReferenceSolution(rawSlug: string): Promise<{
  files: Array<{ path: string; content: string }>;
  explanationMarkdown: string;
} | null> {
  const slug = normalizeSlug(rawSlug);
  if (!slug) return null;

  const supabase = getSupabaseAdminClient();
  if (supabase) {
    const remoteFiles = await downloadBucketFolder(
      `challenges/${slug}/solution/reference`,
      "src/"
    );
    if (remoteFiles && remoteFiles.length > 0) {
      let explanationMarkdown = "";
      try {
        const { data: expBlob } = await supabase.storage
          .from(PRIVATE_BUCKET)
          .download(`challenges/${slug}/solution/explanation.md`);
        if (expBlob) explanationMarkdown = await expBlob.text();
      } catch {
        // optional explanation
      }
      return { files: remoteFiles, explanationMarkdown };
    }
  }

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
