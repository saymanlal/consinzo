#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import type { ProjectFile } from "@consinzo/shared";
import { validateChallengeDirectory } from "@consinzo/validators";
import { EvmRunner, detectFoundryToolchain } from "./index";

function collectProjectFiles(rootDir: string): ProjectFile[] {
  const files: ProjectFile[] = [];
  for (const sub of ["src", "test"]) {
    const dir = path.join(rootDir, sub);
    if (!fs.existsSync(dir)) continue;
    const walk = (cur: string) => {
      for (const entry of fs.readdirSync(cur, { withFileTypes: true })) {
        const abs = path.join(cur, entry.name);
        if (entry.isDirectory()) {
          walk(abs);
        } else if (entry.name.endsWith(".sol")) {
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
  const runner = new EvmRunner();

  if (!cmd || cmd === "--help" || cmd === "help") {
    console.log(`CONSINZO Local EVM Runner (Mode B)
Usage:
  pnpm cli -- doctor               Check installed solc / Foundry / EthereumJS toolchain
  pnpm cli -- compile <dir>        Compile Solidity project in <dir>/src and <dir>/test
  pnpm cli -- test <dir>           Run public tests in <dir> (native forge if available, else solc+EthereumJS EVM)
  pnpm cli -- validate <chalDir>   Validate a CONSINZO challenge package
`);
    process.exit(0);
  }

  if (cmd === "doctor") {
    const info = await detectFoundryToolchain();
    console.log(
      JSON.stringify(
        {
          ecosystem: "ethereum-evm",
          nativeForge: info.forgeAvailable ? info.forgeVersion : "not installed (using bundled solc + EthereumJS EVM)",
          nativeSolc: info.solcAvailable ? info.solcVersion : "not installed globally (using bundled solc@0.8.28)",
          bundledSolc: "0.8.28",
          bundledEvm: "@ethereumjs/evm",
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

  // Support passing either a challenge root (containing starter/) or a starter/ dir directly
  const projectDir = fs.existsSync(path.join(absDir, "starter"))
    ? path.join(absDir, "starter")
    : absDir;
  const files = collectProjectFiles(projectDir);

  if (files.length === 0) {
    console.error(`No .sol files found under ${projectDir}/{src,test}`);
    process.exit(1);
  }

  if (cmd === "compile") {
    const res = await runner.compile(files);
    console.log(JSON.stringify(res, null, 2));
    process.exit(res.compiled ? 0 : 1);
  }

  if (cmd === "test") {
    const report = await runner.runTests(files, { mode: "local-cli", preferNativeForge: true });
    console.log(JSON.stringify(report, null, 2));
    process.exit(report.status === "passed" ? 0 : 1);
  }

  console.error(`Unknown command: ${cmd}`);
  process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
