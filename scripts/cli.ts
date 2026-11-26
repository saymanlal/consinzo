#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import YAML from "yaml";
import type { ProjectFile } from "../packages/shared/src/index";
import { validateChallengeDirectory } from "../packages/validators/src/index";
import { EvmRunner, detectFoundryToolchain } from "../runners/evm/src/index";
import { NearRunner } from "../runners/near/src/index";

type CliEcosystem = "ethereum-evm" | "near";

function detectChallengeEcosystem(baseDir: string): CliEcosystem {
  const manifestPath = path.join(baseDir, "challenge.yaml");
  if (fs.existsSync(manifestPath)) {
    const raw = YAML.parse(fs.readFileSync(manifestPath, "utf8")) as { ecosystem?: string } | null;
    if (raw?.ecosystem === "near") return "near";
  }
  const starterSrc = path.join(baseDir, "starter", "src");
  const directSrc = path.join(baseDir, "src");
  const scanDir = fs.existsSync(starterSrc) ? starterSrc : directSrc;
  if (fs.existsSync(scanDir)) {
    const entries = fs.readdirSync(scanDir);
    if (entries.some((f) => f.endsWith(".ts") || f.endsWith(".js")) && !entries.some((f) => f.endsWith(".sol"))) {
      return "near";
    }
  }
  return "ethereum-evm";
}

function collectProjectFiles(rootDir: string, extensions: string[]): ProjectFile[] {
  const files: ProjectFile[] = [];
  for (const sub of ["src", "test"]) {
    const dir = path.join(rootDir, sub);
    if (!fs.existsSync(dir)) continue;
    const walk = (cur: string) => {
      for (const entry of fs.readdirSync(cur, { withFileTypes: true })) {
        const abs = path.join(cur, entry.name);
        if (entry.isDirectory()) {
          walk(abs);
        } else if (extensions.some((ext) => entry.name.endsWith(ext))) {
          files.push({
            path: path.relative(rootDir, abs).replaceAll("\\", "/"),
            content: fs.readFileSync(abs, "utf8"),
          });
        }
      }
    };
    walk(dir);
  }
  return files;
}

async function main() {
  const [cmd, targetArg] = process.argv.slice(2);

  if (!cmd || cmd === "--help" || cmd === "help") {
    console.log(`CONSINZO Local Multi-Ecosystem Runner (Mode B)
Usage:
  pnpm cli -- doctor               Check installed EVM (solc/forge) and NEAR TypeScript toolchains
  pnpm cli -- compile <dir>        Compile Solidity (.sol) or NEAR TypeScript (.ts) project
  pnpm cli -- test <dir>           Run public tests in <dir> for EVM or NEAR
  pnpm cli -- validate <chalDir>   Validate a CONSINZO challenge package
`);
    process.exit(0);
  }

  if (cmd === "doctor") {
    const info = await detectFoundryToolchain();
    console.log(
      JSON.stringify(
        {
          ecosystems: {
            "ethereum-evm": {
              supportLevel: 4,
              nativeForge: info.forgeAvailable
                ? info.forgeVersion
                : "not installed (using bundled solc + EthereumJS EVM)",
              nativeSolc: info.solcAvailable
                ? info.solcVersion
                : "not installed globally (using bundled solc@0.8.28)",
              bundledSolc: "0.8.28",
              bundledEvm: "@ethereumjs/evm",
            },
            near: {
              supportLevel: 3,
              runner: "near-ts-vm (TypeScript strict check + node:vm near-sdk-js shim)",
              nodeVersion: process.version,
            },
          },
        },
        null,
        2
      )
    );
    return;
  }

  if (!targetArg) {
    console.error(`Missing target directory for command "${cmd}".`);
    process.exit(1);
  }

  const absDir = path.resolve(process.cwd(), targetArg);

  if (cmd === "validate") {
    const res = validateChallengeDirectory(absDir);
    console.log(JSON.stringify(res, null, 2));
    process.exit(res.valid ? 0 : 1);
  }

  const ecosystem = detectChallengeEcosystem(absDir);
  const projectDir = fs.existsSync(path.join(absDir, "starter"))
    ? path.join(absDir, "starter")
    : absDir;
  const exts = ecosystem === "near" ? [".ts", ".js"] : [".sol"];
  const files = collectProjectFiles(projectDir, exts);

  if (files.length === 0) {
    console.error(`No ${exts.join("/")} files found under ${projectDir}/{src,test}`);
    process.exit(1);
  }

  const runner = ecosystem === "near" ? new NearRunner() : new EvmRunner();

  if (cmd === "compile") {
    const res = await runner.compile(files);
    console.log(JSON.stringify({ ecosystem, ...res }, null, 2));
    process.exit(res.compiled ? 0 : 1);
  }

  if (cmd === "test") {
    const report =
      ecosystem === "near"
        ? await new NearRunner().runTests(files, { mode: "local-cli" })
        : await new EvmRunner().runTests(files, { mode: "local-cli", preferNativeForge: true });
    console.log(JSON.stringify({ ecosystem, ...report }, null, 2));
    process.exit(report.status === "passed" ? 0 : 1);
  }

  console.error(`Unknown command: ${cmd}`);
  process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
