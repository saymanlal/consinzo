import vm from "node:vm";
import ts from "typescript";
import type {
  CompilerDiagnostic,
  EcosystemRunner,
  ExecutionReport,
  PublicTestResult,
} from "@consinzo/execution-sdk";
import { sanitizeLogs } from "@consinzo/runner-common";
import type { ExecutionMode, ProjectFile } from "@consinzo/shared";
import { NEAR_SDK_SHIM_TS } from "./near-shim";

interface NearCompileResult {
  compiled: boolean;
  compilerVersion: string;
  diagnostics: CompilerDiagnostic[];
  transpiledModules: Map<string, string>;
}

function compileNearTypeScript(files: ProjectFile[]): NearCompileResult {
  const fileMap = new Map<string, string>();
  for (const f of files) {
    const norm = f.path.replaceAll("\\", "/").replace(/^\.\//, "");
    if (norm.endsWith(".ts") || norm.endsWith(".js")) {
      fileMap.set(norm, f.content);
    }
  }
  fileMap.set("near-sdk-js/index.ts", NEAR_SDK_SHIM_TS);

  const diagnostics: CompilerDiagnostic[] = [];
  const transpiledModules = new Map<string, string>();

  const compilerOptions: ts.CompilerOptions = {
    target: ts.ScriptTarget.ES2022,
    module: ts.ModuleKind.CommonJS,
    strict: true,
    noImplicitAny: true,
    esModuleInterop: true,
    skipLibCheck: true,
    types: [],
  };

  const host = ts.createCompilerHost(compilerOptions);
  const origGetSourceFile = host.getSourceFile.bind(host);
  const origFileExists = host.fileExists.bind(host);
  const origReadFile = host.readFile.bind(host);

  const resolveVirtualPath = (p: string): string | undefined => {
    const norm = p.replaceAll("\\", "/").replace(/^\.\//, "");
    if (fileMap.has(norm)) return norm;
    if (fileMap.has(`${norm}.ts`)) return `${norm}.ts`;
    if (fileMap.has(`${norm}.js`)) return `${norm}.js`;
    for (const key of fileMap.keys()) {
      if (
        norm.endsWith(`/${key}`) ||
        `${norm}.ts`.endsWith(`/${key}`) ||
        `${norm}.js`.endsWith(`/${key}`)
      ) {
        return key;
      }
    }
    return undefined;
  };

  host.fileExists = (fileName: string) => {
    return Boolean(resolveVirtualPath(fileName)) || origFileExists(fileName);
  };
  host.readFile = (fileName: string) => {
    const v = resolveVirtualPath(fileName);
    return v ? fileMap.get(v) : origReadFile(fileName);
  };
  host.getSourceFile = (fileName: string, languageVersion: ts.ScriptTarget) => {
    const v = resolveVirtualPath(fileName);
    if (v) {
      return ts.createSourceFile(v, fileMap.get(v)!, languageVersion);
    }
    return origGetSourceFile(fileName, languageVersion);
  };
  host.resolveModuleNames = (moduleNames: string[], containingFile: string) => {
    return moduleNames.map((modName) => {
      if (modName === "near-sdk-js" || modName.endsWith("near-sdk-js")) {
        return { resolvedFileName: "near-sdk-js/index.ts", extension: ts.Extension.Ts, isExternalLibraryImport: false };
      }
      const baseDir = containingFile.includes("/")
        ? containingFile.slice(0, containingFile.lastIndexOf("/"))
        : "";
      const joined = baseDir ? `${baseDir}/${modName}` : modName;
      const parts: string[] = [];
      for (const seg of joined.split("/")) {
        if (seg === "..") parts.pop();
        else if (seg && seg !== ".") parts.push(seg);
      }
      const resolved = resolveVirtualPath(parts.join("/"));
      if (resolved) {
        return { resolvedFileName: resolved, extension: ts.Extension.Ts, isExternalLibraryImport: false };
      }
      return undefined;
    });
  };

  const rootNames = Array.from(fileMap.keys());
  const program = ts.createProgram(rootNames, compilerOptions, host);
  const allDiagnostics = ts
    .getPreEmitDiagnostics(program)
    .filter((d) => !d.file || fileMap.has(d.file.fileName));

  let hasError = false;
  for (const d of allDiagnostics) {
    if (d.category === ts.DiagnosticCategory.Error) hasError = true;
    const file = d.file?.fileName ?? "unknown";
    const pos =
      d.file && typeof d.start === "number"
        ? d.file.getLineAndCharacterOfPosition(d.start)
        : undefined;
    diagnostics.push({
      severity: d.category === ts.DiagnosticCategory.Error ? "error" : "warning",
      file,
      line: pos ? pos.line + 1 : undefined,
      column: pos ? pos.character + 1 : undefined,
      code: String(d.code),
      message: ts.flattenDiagnosticMessageText(d.messageText, "\n"),
    });
  }

  if (!hasError) {
    for (const [filePath, source] of fileMap.entries()) {
      const out = ts.transpileModule(source, { compilerOptions });
      transpiledModules.set(filePath, out.outputText);
    }
  }

  return {
    compiled: !hasError,
    compilerVersion: `typescript@${ts.version}`,
    diagnostics,
    transpiledModules,
  };
}

function executeNearTestSuite(
  transpiledModules: Map<string, string>,
  testFilePrefix: string,
  timeoutMs: number
): PublicTestResult[] {
  const results: PublicTestResult[] = [];
  const moduleCache = new Map<string, { exports: Record<string, unknown> }>();

  const loadModule = (modulePath: string, fromFile: string): Record<string, unknown> => {
    let target = modulePath;
    if (modulePath === "near-sdk-js") {
      target = "near-sdk-js/index.ts";
    } else if (modulePath.startsWith(".")) {
      const baseDir = fromFile.includes("/")
        ? fromFile.slice(0, fromFile.lastIndexOf("/"))
        : "";
      const joined = baseDir ? `${baseDir}/${modulePath}` : modulePath;
      const parts: string[] = [];
      for (const seg of joined.split("/")) {
        if (seg === "..") parts.pop();
        else if (seg && seg !== ".") parts.push(seg);
      }
      const norm = parts.join("/");
      target = transpiledModules.has(norm)
        ? norm
        : transpiledModules.has(`${norm}.ts`)
          ? `${norm}.ts`
          : `${norm}.js`;
    }

    if (moduleCache.has(target)) return moduleCache.get(target)!.exports;
    const code = transpiledModules.get(target);
    if (!code) throw new Error(`Module not found in workspace: ${modulePath}`);

    const mod = { exports: {} as Record<string, unknown> };
    moduleCache.set(target, mod);

    const sandbox = {
      exports: mod.exports,
      module: mod,
      require: (reqPath: string) => loadModule(reqPath, target),
      BigInt,
      Map,
      Set,
      Error,
      JSON,
      Math,
      Object,
      Array,
      String,
      Number,
      Boolean,
    };

    const script = new vm.Script(code, { filename: target });
    script.runInNewContext(sandbox, { timeout: timeoutMs });
    return mod.exports;
  };

  for (const filePath of transpiledModules.keys()) {
    if (!filePath.startsWith(testFilePrefix)) continue;
    moduleCache.clear();
    const testExports = loadModule(filePath, filePath);
    const contractName = filePath.split("/").pop()?.replace(/\.(t\.)?(ts|js)$/, "") ?? "NearTest";

    for (const [fnName, fn] of Object.entries(testExports)) {
      if (!fnName.startsWith("test") || typeof fn !== "function") continue;
      const started = Date.now();
      try {
        (fn as () => void)();
        results.push({
          name: fnName,
          contract: contractName,
          passed: true,
          durationMs: Date.now() - started,
        });
      } catch (err) {
        results.push({
          name: fnName,
          contract: contractName,
          passed: false,
          durationMs: Date.now() - started,
          reason: (err as Error).message,
        });
      }
    }
  }

  return results;
}

export class NearRunner implements EcosystemRunner {
  public readonly ecosystemId = "near";
  public readonly supportedModes: ExecutionMode[] = ["local-cli"];

  async compile(files: ProjectFile[]) {
    const res = compileNearTypeScript(files);
    return {
      compiled: res.compiled,
      compilerVersion: res.compilerVersion,
      diagnostics: res.diagnostics,
    };
  }

  async runTests(
    files: ProjectFile[],
    options: {
      timeoutMs?: number;
      includeHiddenFiles?: ProjectFile[];
      mode?: ExecutionMode;
    } = {}
  ): Promise<ExecutionReport> {
    const started = Date.now();
    const timeoutMs = options.timeoutMs ?? 10_000;
    const mode = options.mode ?? "local-cli";
    const rawLogs: string[] = [];

    const publicComp = compileNearTypeScript(files);
    rawLogs.push(
      `[near-ts ${publicComp.compilerVersion}] compiled=${publicComp.compiled} diagnostics=${publicComp.diagnostics.length}`
    );

    if (!publicComp.compiled) {
      for (const d of publicComp.diagnostics) {
        rawLogs.push(`[${d.severity}] ${d.file}:${d.line ?? 0}: ${d.message}`);
      }
      const sanitized = sanitizeLogs(rawLogs);
      return {
        status: "compilation_error",
        mode,
        runnerName: "near-ts-vm",
        compilerVersion: publicComp.compilerVersion,
        compiled: false,
        diagnostics: publicComp.diagnostics,
        publicTests: [],
        totalDurationMs: Date.now() - started,
        sanitizedLogs: sanitized.logs,
        truncatedLogs: sanitized.truncated,
      };
    }

    const publicTests = executeNearTestSuite(publicComp.transpiledModules, "test/", timeoutMs);
    for (const t of publicTests) {
      rawLogs.push(
        `[${t.passed ? "PASS" : "FAIL"}] ${t.contract}.${t.name}() (${t.durationMs}ms)${
          t.reason ? ` — ${t.reason}` : ""
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

    if (options.includeHiddenFiles && options.includeHiddenFiles.length > 0) {
      const userSrcOnly = files.filter((f) => !f.path.startsWith("test/"));
      const hiddenComp = compileNearTypeScript([...userSrcOnly, ...options.includeHiddenFiles]);
      if (!hiddenComp.compiled) {
        allHiddenPassed = false;
        hiddenSummary = {
          evaluated: true,
          total: 1,
          passed: 0,
          failed: 1,
          notice: "Hidden suite compilation failed.",
        };
      } else {
        const hiddenResults = executeNearTestSuite(
          hiddenComp.transpiledModules,
          "evaluation/",
          timeoutMs
        );
        const hPassed = hiddenResults.filter((r) => r.passed).length;
        const hTotal = hiddenResults.length;
        allHiddenPassed = hTotal > 0 && hPassed === hTotal;
        hiddenSummary = {
          evaluated: true,
          total: hTotal,
          passed: hPassed,
          failed: hTotal - hPassed,
          notice: "Hidden invariant suite evaluated server-side.",
        };
        rawLogs.push(`[hidden-eval] ${hPassed}/${hTotal} hidden assertions passed.`);
      }
    }

    const allPublicPassed = publicTests.length > 0 && publicTests.every((t) => t.passed);
    const sanitized = sanitizeLogs(rawLogs);

    return {
      status: allPublicPassed && allHiddenPassed ? "passed" : "failed",
      mode,
      runnerName: "near-ts-vm",
      compilerVersion: publicComp.compilerVersion,
      compiled: true,
      diagnostics: publicComp.diagnostics,
      publicTests,
      hiddenTestsSummary: hiddenSummary,
      totalDurationMs: Date.now() - started,
      sanitizedLogs: sanitized.logs,
      truncatedLogs: sanitized.truncated,
    };
  }
}
