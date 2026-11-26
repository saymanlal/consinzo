import fs from "node:fs";
import path from "node:path";
import YAML from "yaml";
import { createClient } from "@supabase/supabase-js";
import { ChallengeManifestSchema } from "../packages/challenge-spec/src/index";

async function main() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const bucket = process.env.CONSINZO_PRIVATE_BUCKET || "consinzo-private";

  if (!supabaseUrl || !serviceRoleKey) {
    console.error(
      "Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in environment."
    );
    process.exit(1);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // 1. Ensure private bucket exists (public: false)
  const { data: buckets } = await supabase.storage.listBuckets();
  if (!buckets?.some((b) => b.name === bucket)) {
    const { error } = await supabase.storage.createBucket(bucket, {
      public: false,
      fileSizeLimit: 1024 * 1024,
    });
    if (error) throw error;
    console.log(`Created private bucket "${bucket}".`);
  }

  const challengesRoot = path.resolve(process.cwd(), "content/challenges");
  const slugs = fs
    .readdirSync(challengesRoot, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name)
    .sort();

  for (const slug of slugs) {
    const dir = path.join(challengesRoot, slug);
    const manifestPath = path.join(dir, "challenge.yaml");
    if (!fs.existsSync(manifestPath)) continue;

    const parsed = ChallengeManifestSchema.safeParse(
      YAML.parse(fs.readFileSync(manifestPath, "utf8"))
    );
    if (!parsed.success) {
      console.warn(`Skipping invalid manifest: ${slug}`);
      continue;
    }
    const m = parsed.data;

    // 2. Upsert language & challenge metadata into Supabase PostgreSQL
    const langId = `${m.ecosystem}-${m.language.toLowerCase()}`;
    await supabase.from("languages").upsert(
      {
        id: langId,
        name: m.language,
        monaco_language_id: m.language.toLowerCase() === "solidity" ? "sol" : m.language.toLowerCase(),
        ecosystem_id: m.ecosystem,
      },
      { onConflict: "id" }
    );

    const { data: chalRow, error: chalErr } = await supabase
      .from("challenges")
      .upsert(
        {
          slug: m.slug,
          title: m.title,
          description: m.description,
          ecosystem_id: m.ecosystem,
          language_id: langId,
          category_id: m.category,
          difficulty: m.difficulty,
          publication_status: m.publication_status,
          is_security_mission: m.is_security_mission,
          max_points: m.scoring.max_points,
        },
        { onConflict: "slug" }
      )
      .select("id")
      .single();

    if (chalErr || !chalRow) {
      console.error(`Failed syncing challenge ${slug}:`, chalErr?.message);
      continue;
    }

    // 3. Upload private evaluation/hidden and solution/ files to private storage bucket
    const uploadTree = async (localDir: string, remotePrefix: string) => {
      if (!fs.existsSync(localDir)) return 0;
      let count = 0;
      const walk = async (cur: string) => {
        for (const entry of fs.readdirSync(cur, { withFileTypes: true })) {
          const abs = path.join(cur, entry.name);
          if (entry.isDirectory()) {
            await walk(abs);
          } else {
            const rel = path.relative(localDir, abs).replaceAll("\\", "/");
            const objectKey = `${remotePrefix}/${rel}`;
            const content = fs.readFileSync(abs);
            const { error: upErr } = await supabase.storage
              .from(bucket)
              .upload(objectKey, content, {
                upsert: true,
                contentType: "text/plain; charset=utf-8",
              });
            if (upErr) throw upErr;
            count++;
          }
        }
      };
      await walk(localDir);
      return count;
    };

    const hiddenCount = await uploadTree(
      path.join(dir, "evaluation/hidden"),
      `challenges/${slug}/evaluation/hidden`
    );
    const solutionCount = await uploadTree(
      path.join(dir, "solution"),
      `challenges/${slug}/solution`
    );

    console.log(
      `Synced ${slug}: db=${chalRow.id}, hidden_files=${hiddenCount}, solution_files=${solutionCount}`
    );
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
