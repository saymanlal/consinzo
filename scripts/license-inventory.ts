import fs from "node:fs";
import path from "node:path";

interface LicenseRecord {
  package: string;
  version: string;
  license: string;
  repository?: string;
}

function collectLicenses(): LicenseRecord[] {
  const records: LicenseRecord[] = [];
  const seen = new Set<string>();
  const pnpmStore = path.resolve(process.cwd(), "node_modules/.pnpm");
  if (!fs.existsSync(pnpmStore)) return records;

  for (const entry of fs.readdirSync(pnpmStore, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const nmDir = path.join(pnpmStore, entry.name, "node_modules");
    if (!fs.existsSync(nmDir)) continue;

    const scanPkg = (pkgDir: string) => {
      const pkgJsonPath = path.join(pkgDir, "package.json");
      if (!fs.existsSync(pkgJsonPath)) return;
      try {
        const pkg = JSON.parse(fs.readFileSync(pkgJsonPath, "utf8")) as {
          name?: string;
          version?: string;
          license?: string | { type?: string };
          repository?: string | { url?: string };
        };
        if (!pkg.name || !pkg.version) return;
        const key = `${pkg.name}@${pkg.version}`;
        if (seen.has(key)) return;
        seen.add(key);
        const licenseStr =
          typeof pkg.license === "string"
            ? pkg.license
            : pkg.license?.type ?? "UNSPECIFIED";
        const repoStr =
          typeof pkg.repository === "string" ? pkg.repository : pkg.repository?.url;
        records.push({
          package: pkg.name,
          version: pkg.version,
          license: licenseStr,
          repository: repoStr,
        });
      } catch {
        // skip unreadable package.json
      }
    };

    for (const mod of fs.readdirSync(nmDir, { withFileTypes: true })) {
      if (!mod.isDirectory()) continue;
      if (mod.name.startsWith("@")) {
        const scopeDir = path.join(nmDir, mod.name);
        for (const sub of fs.readdirSync(scopeDir, { withFileTypes: true })) {
          if (sub.isDirectory()) scanPkg(path.join(scopeDir, sub.name));
        }
      } else {
        scanPkg(path.join(nmDir, mod.name));
      }
    }
  }

  return records.sort((a, b) => a.package.localeCompare(b.package));
}

const records = collectLicenses();
const counts = new Map<string, number>();
for (const r of records) {
  counts.set(r.license, (counts.get(r.license) ?? 0) + 1);
}

const lines: string[] = [
  "# CONSINZO Third-Party Open-Source License Inventory",
  "",
  `Generated: ${new Date().toISOString().slice(0, 10)}`,
  "",
  "CONSINZO is proprietary software. The following third-party open-source packages are used internally under their original licenses.",
  "",
  "## License Summary",
  "",
  "| License | Package Count |",
  "|---|---|",
  ...Array.from(counts.entries())
    .sort((a, b) => b[1] - a[1])
    .map(([lic, cnt]) => `| ${lic} | ${cnt} |`),
  "",
  "## Packages",
  "",
  "| Package | Version | License |",
  "|---|---|---|",
  ...records.map((r) => `| ${r.package} | ${r.version} | ${r.license} |`),
  "",
];

fs.mkdirSync(path.resolve(process.cwd(), "docs"), { recursive: true });
fs.writeFileSync(path.resolve(process.cwd(), "docs/THIRD-PARTY-LICENSES.md"), lines.join("\n"));
console.log(`Recorded ${records.length} third-party dependencies in docs/THIRD-PARTY-LICENSES.md`);
