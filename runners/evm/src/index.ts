import type {
  EcosystemRunner,
  ExecutionReport,
} from "@consinzo/execution-sdk";
import { sanitizeLogs } from "@consinzo/runner-common";
import type { ExecutionMode, ProjectFile } from "@consinzo/shared";
import { compileSolidityProject } from "./compiler";
import { runSolidityTestsInEvm } from "./evm-runner";
import { detectFoundryToolchain, runWithNativeForge } from "./foundry-cli";

export { compileSolidityProject } from "./compiler";
export { runSolidityTestsInEvm } from "./evm-runner";
export { detectFoundryToolchain, runWithNativeForge } from "./foundry-cli";

export class EvmRunner implements EcosystemRunner {
  public readonly ecosystemId = "ethereum-evm";
  public readonly supportedModes: ExecutionMode[] = ["browser-worker", "local-cli"];

  async compile(files: ProjectFile[]) {
    const res = compileSolidityProject(files);
    return {
      compiled: res.compiled,
      compilerVersion: res.compilerVersion,
      diagnostics: res.diagnostics,
      artifacts: res.compiled
        ? Object.fromEntries(
            res.contracts.map((c) => [
              `${c.sourcePath}:${c.contractName}`,
              { abi: c.abi, bytecodeLength: c.bytecode.length / 2 },
            ])
          )
        : undefined,
    };
  }

  async runTests(
    files: ProjectFile[],
    options: {
      timeoutMs?: number;
      includeHiddenFiles?: ProjectFile[];
      mode?: ExecutionMode;
      preferNativeForge?: boolean;
    } = {}
  ): Promise<ExecutionReport> {
    const mode = options.mode ?? "local-cli";
    const timeoutMs = options.timeoutMs ?? 15_000;
    const rawLogs: string[] = [];

    // Try native forge if explicitly requested and available on host
    if (options.preferNativeForge && mode === "local-cli") {
      const toolchain = await detectFoundryToolchain();
      if (toolchain.forgeAvailable) {
        try {
          const allFiles = [...files, ...(options.includeHiddenFiles ?? [])];
          const forgeRes = await runWithNativeForge(allFiles, timeoutMs);
          rawLogs.push(
            `[foundry] ${toolchain.forgeVersion ?? "forge"} executed ${forgeRes.results.length} test(s)`
          );
          rawLogs.push(...forgeRes.logs);
          const publicNames = new Set(
            files.filter((f) => f.path.startsWith("test/")).map((f) => f.path)
          );
          const publicTests = forgeRes.results.filter(
            (r) => publicNames.size === 0 || !r.name.startsWith("testHidden")
          );
          const hiddenTests = forgeRes.results.filter((r) => r.name.startsWith("testHidden"));
          const sanitized = sanitizeLogs(rawLogs);
          const allPassed = forgeRes.results.every((r) => r.passed);
          return {
            status: allPassed ? "passed" : "failed",
            mode,
            runnerName: "foundry-forge-cli",
            compilerVersion: toolchain.solcVersion ?? "solc",
            compiled: true,
            diagnostics: [],
            publicTests,
            hiddenTestsSummary: {
              evaluated: hiddenTests.length > 0,
              total: hiddenTests.length,
              passed: hiddenTests.filter((t) => t.passed).length,
              failed: hiddenTests.filter((t) => !t.passed).length,
            },
            totalDurationMs: forgeRes.results.reduce((acc, r) => acc + r.durationMs, 0),
            sanitizedLogs: sanitized.logs,
            truncatedLogs: sanitized.truncated,
          };
        } catch (err) {
          rawLogs.push(`[foundry] fallback to EthereumJS EVM (${(err as Error).message})`);
        }
      }
    }

    // Primary real solc + EthereumJS EVM execution
    const publicExec = await runSolidityTestsInEvm(files, { timeoutMs });
    rawLogs.push(
      `[solc ${publicExec.compilerVersion}] compiled=${publicExec.compiled} diagnostics=${publicExec.diagnostics.length}`
    );

    if (!publicExec.compiled) {
      for (const d of publicExec.diagnostics) {
        rawLogs.push(`[${d.severity}] ${d.file}:${d.line ?? 0}: ${d.message}`);
      }
      const sanitized = sanitizeLogs(rawLogs);
      return {
        status: "compilation_error",
        mode,
        runnerName: "solc-ethereumjs-evm",
        compilerVersion: publicExec.compilerVersion,
        compiled: false,
        diagnostics: publicExec.diagnostics,
        publicTests: [],
        totalDurationMs: publicExec.totalDurationMs,
        sanitizedLogs: sanitized.logs,
        truncatedLogs: sanitized.truncated,
      };
    }

    for (const r of publicExec.results) {
      rawLogs.push(
        `[${r.passed ? "PASS" : "FAIL"}] ${r.contract}.${r.name}() (${r.gasUsed ?? 0} gas, ${r.durationMs}ms)${
          r.reason ? ` — ${r.reason}` : ""
        }`
      );
    }

    let hiddenSummary: ExecutionReport["hiddenTestsSummary"] = {
      evaluated: false,
      total: 0,
      passed: 0,
      failed: 0,
      notice: "No hidden tests supplied for this run.",
    };

    let allHiddenPassed = true;
    let totalDurationMs = publicExec.totalDurationMs;

    if (options.includeHiddenFiles && options.includeHiddenFiles.length > 0) {
      // Strip user-submitted test/ files when running hidden suite so user cannot interfere
      const userSrcOnly = files.filter((f) => !f.path.startsWith("test/"));
      const hiddenFiles = [...userSrcOnly, ...options.includeHiddenFiles];
      const hiddenExec = await runSolidityTestsInEvm(hiddenFiles, {
        timeoutMs,
        targetTestFilePrefix: "evaluation/",
      });
      totalDurationMs += hiddenExec.totalDurationMs;
      const hPassed = hiddenExec.results.filter((r) => r.passed).length;
      const hTotal = hiddenExec.results.length;
      allHiddenPassed = hiddenExec.compiled && hTotal > 0 && hPassed === hTotal;
      hiddenSummary = {
        evaluated: true,
        total: hTotal,
        passed: hPassed,
        failed: hTotal - hPassed,
        notice: "Hidden invariant suite evaluated server-side; individual hidden test details remain private.",
      };
      rawLogs.push(`[hidden-eval] ${hPassed}/${hTotal} hidden assertions passed.`);
    }

    const gasSamples = publicExec.results
      .map((r) => r.gasUsed)
      .filter((g): g is number => typeof g === "number" && g > 0);
    const averageGasUsed =
      gasSamples.length > 0
        ? Math.round(gasSamples.reduce((a, b) => a + b, 0) / gasSamples.length)
        : undefined;

    const allPublicPassed =
      publicExec.results.length > 0 && publicExec.results.every((r) => r.passed);
    const sanitized = sanitizeLogs(rawLogs);

    return {
      status: allPublicPassed && allHiddenPassed ? "passed" : "failed",
      mode,
      runnerName: "solc-ethereumjs-evm",
      compilerVersion: publicExec.compilerVersion,
      compiled: true,
      diagnostics: publicExec.diagnostics,
      publicTests: publicExec.results,
      hiddenTestsSummary: hiddenSummary,
      totalDurationMs,
      averageGasUsed,
      sanitizedLogs: sanitized.logs,
      truncatedLogs: sanitized.truncated,
    };
  }
}
