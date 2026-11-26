import fs from "node:fs";
import path from "node:path";
import { ECOSYSTEM_REGISTRY } from "../packages/ecosystem-registry/src/index";
import { CHALLENGE_CATEGORIES, type ProjectFile } from "../packages/shared/src/index";
import { validateChallengeDirectory } from "../packages/validators/src/index";
import { EvmRunner } from "../runners/evm/src/index";

function readSolFiles(dir: string, mountPrefix: string): ProjectFile[] {
  if (!fs.existsSync(dir)) return [];
  const results: ProjectFile[] = [];
  const walk = (cur: string) => {
    for (const entry of fs.readdirSync(cur, { withFileTypes: true })) {
      const abs = path.join(cur, entry.name);
      if (entry.isDirectory()) {
        walk(abs);
      } else if (entry.name.endsWith(".sol")) {
        const rel = path.relative(dir, abs).replaceAll("\\", "/");
        results.push({
          path: `${mountPrefix}${rel}`,
          content: fs.readFileSync(abs, "utf8"),
        });
      }
    }
  };
  walk(dir);
  return results;
}

async function main() {
  const challengesRoot = path.resolve(process.cwd(), "content/challenges");
  const slugs = fs
    .readdirSync(challengesRoot, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name)
    .sort();

  const runner = new EvmRunner();
  const seenIds = new Set<string>();
  const seenSlugs = new Set<string>();
  const validEcosystemIds = new Set(ECOSYSTEM_REGISTRY.map((e) => e.id));
  const validCategoryIds = new Set(CHALLENGE_CATEGORIES.map((c) => c.id));
  let failures = 0;

  console.log(`Validating ${slugs.length} challenge packages...\n`);

  for (const slug of slugs) {
    const dir = path.join(challengesRoot, slug);
    const validation = validateChallengeDirectory(dir);
    if (!validation.valid || !validation.manifest) {
      console.error(`[FAIL] ${slug} manifest/structure invalid:`, validation.errors);
      failures++;
      continue;
    }

    const m = validation.manifest;
    if (seenIds.has(m.id)) {
      console.error(`[FAIL] ${slug} duplicate challenge id: ${m.id}`);
      failures++;
      continue;
    }
    if (seenSlugs.has(m.slug) || m.slug !== slug) {
      console.error(`[FAIL] ${slug} duplicate or mismatched slug: ${m.slug}`);
      failures++;
      continue;
    }
    if (!validEcosystemIds.has(m.ecosystem)) {
      console.error(`[FAIL] ${slug} invalid ecosystem reference: ${m.ecosystem}`);
      failures++;
      continue;
    }
    if (!validCategoryIds.has(m.category)) {
      console.error(`[FAIL] ${slug} invalid category reference: ${m.category}`);
      failures++;
      continue;
    }
    seenIds.add(m.id);
    seenSlugs.add(m.slug);

    // 1. Verify starter compiles cleanly
    const starterSrc = readSolFiles(path.join(dir, "starter/src"), "src/");
    const starterTest = readSolFiles(path.join(dir, "starter/test"), "test/");
    const starterCompile = await runner.compile([...starterSrc, ...starterTest]);
    if (!starterCompile.compiled) {
      console.error(`[FAIL] ${slug} starter failed to compile:`, starterCompile.diagnostics);
      failures++;
      continue;
    }

    // 2. Verify reference solution passes ALL public AND hidden tests
    const refSrc = readSolFiles(path.join(dir, "solution/reference"), "src/");
    const publicTest = readSolFiles(path.join(dir, "evaluation/public"), "test/");
    const hiddenTest = readSolFiles(path.join(dir, "evaluation/hidden"), "evaluation/hidden/");

    const refReport = await runner.runTests([...refSrc, ...publicTest], {
      mode: "local-cli",
      includeHiddenFiles: hiddenTest,
    });

    if (refReport.status !== "passed") {
      console.error(`[FAIL] ${slug} reference solution failed evaluation:`, {
        status: refReport.status,
        diagnostics: refReport.diagnostics,
        publicTests: refReport.publicTests,
        hiddenTestsSummary: refReport.hiddenTestsSummary,
      });
      failures++;
      continue;
    }

    console.log(
      `[OK] ${slug} (${validation.manifest.difficulty}, ${validation.manifest.category}) — public: ${refReport.publicTests.length}/${refReport.publicTests.length}, hidden: ${refReport.hiddenTestsSummary?.passed}/${refReport.hiddenTestsSummary?.total}, avgGas=${refReport.averageGasUsed ?? 0}`
    );
  }

  console.log(`\nSummary: ${slugs.length - failures}/${slugs.length} challenges validated.`);
  if (failures > 0) {
    process.exit(1);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
