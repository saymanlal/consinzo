import { execFile } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { promisify } from "node:util";
import type { PublicTestResult } from "@consinzo/execution-sdk";
import type { ProjectFile } from "@consinzo/shared";
import { FORGE_STD_TEST_SOL, FORGE_STD_VM_SOL } from "./sol-stdlib";

const execFileAsync = promisify(execFile);

export async function detectFoundryToolchain(): Promise<{
  forgeAvailable: boolean;
  forgeVersion?: string;
  solcAvailable: boolean;
  solcVersion?: string;
}> {
  const result: {
    forgeAvailable: boolean;
    forgeVersion?: string;
    solcAvailable: boolean;
    solcVersion?: string;
  } = {
    forgeAvailable: false,
    solcAvailable: false,
  };

  try {
    const { stdout } = await execFileAsync("forge", ["--version"], { timeout: 3000 });
    result.forgeAvailable = true;
    result.forgeVersion = stdout.trim().split("\n")[0];
  } catch {
    result.forgeAvailable = false;
  }

  try {
    const { stdout } = await execFileAsync("solc", ["--version"], { timeout: 3000 });
    result.solcAvailable = true;
    result.solcVersion = stdout.trim().split("\n").pop();
  } catch {
    result.solcAvailable = false;
  }

  return result;
}

export async function runWithNativeForge(
  files: ProjectFile[],
  timeoutMs = 15_000
): Promise<{
  executed: boolean;
  compiled: boolean;
  results: PublicTestResult[];
  logs: string[];
}> {
  const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), "consinzo-forge-"));
  try {
    fs.writeFileSync(
      path.join(tmpRoot, "foundry.toml"),
      `[profile.default]\nsrc = "src"\ntest = "test"\nlibs = ["lib"]\nremappings = ["forge-std/=lib/forge-std/src/"]\n`
    );

    const stdDir = path.join(tmpRoot, "lib", "forge-std", "src");
    fs.mkdirSync(stdDir, { recursive: true });
    fs.writeFileSync(path.join(stdDir, "Vm.sol"), FORGE_STD_VM_SOL);
    fs.writeFileSync(path.join(stdDir, "Test.sol"), FORGE_STD_TEST_SOL);

    for (const file of files) {
      const target = path.join(tmpRoot, file.path);
      fs.mkdirSync(path.dirname(target), { recursive: true });
      fs.writeFileSync(target, file.content, "utf8");
    }

    const { stdout, stderr } = await execFileAsync("forge", ["test", "--json"], {
      cwd: tmpRoot,
      timeout: timeoutMs,
      maxBuffer: 1024 * 1024,
    });

    const parsed = JSON.parse(stdout) as Record<
      string,
      {
        test_results?: Record<
          string,
          {
            status: string;
            reason?: string;
            kind?: { Standard?: number };
            duration?: { secs?: number; nanos?: number };
          }
        >;
      }
    >;

    const results: PublicTestResult[] = [];
    for (const [contractKey, suite] of Object.entries(parsed)) {
      const contractName = contractKey.split(":").pop() ?? contractKey;
      for (const [fnSig, outcome] of Object.entries(suite.test_results ?? {})) {
        const fnName = fnSig.replace(/\(\)$/, "");
        const ms =
          ((outcome.duration?.secs ?? 0) * 1000) +
          Math.round((outcome.duration?.nanos ?? 0) / 1_000_000);
        results.push({
          name: fnName,
          contract: contractName,
          passed: outcome.status === "Success",
          gasUsed: outcome.kind?.Standard,
          durationMs: ms,
          reason: outcome.reason || undefined,
        });
      }
    }

    return {
      executed: true,
      compiled: true,
      results,
      logs: stderr ? stderr.split("\n").filter(Boolean) : [],
    };
  } finally {
    fs.rmSync(tmpRoot, { recursive: true, force: true });
  }
}
