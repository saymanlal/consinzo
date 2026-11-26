/// <reference path="./solc.d.ts" />
import solc from "solc";
import type { CompilerDiagnostic } from "@consinzo/execution-sdk";
import type { ProjectFile } from "@consinzo/shared";
import { FORGE_STD_TEST_SOL, FORGE_STD_VM_SOL } from "./sol-stdlib";

export interface CompiledContractArtifact {
  sourcePath: string;
  contractName: string;
  abi: unknown[];
  bytecode: string;
  deployedBytecode: string;
}

export interface SolcCompilationOutput {
  compiled: boolean;
  compilerVersion: string;
  diagnostics: CompilerDiagnostic[];
  contracts: CompiledContractArtifact[];
}

interface SolcRawError {
  severity: "error" | "warning" | "info";
  formattedMessage: string;
  message: string;
  errorCode?: string;
  sourceLocation?: {
    file: string;
    start: number;
    end: number;
  };
}

function computeLineCol(content: string, offset: number): { line: number; column: number } {
  const safeOffset = Math.max(0, Math.min(offset, content.length));
  const slice = content.slice(0, safeOffset);
  const lines = slice.split("\n");
  return {
    line: lines.length,
    column: (lines[lines.length - 1]?.length ?? 0) + 1,
  };
}

export function compileSolidityProject(files: ProjectFile[]): SolcCompilationOutput {
  const fileMap = new Map<string, string>();
  for (const f of files) {
    const normalized = f.path.replaceAll("\\", "/").replace(/^\.\//, "");
    if (normalized.endsWith(".sol")) {
      fileMap.set(normalized, f.content);
    }
  }

  // Inject Foundry-compatible stdlib shims if not overridden
  if (!fileMap.has("forge-std/Vm.sol")) {
    fileMap.set("forge-std/Vm.sol", FORGE_STD_VM_SOL);
  }
  if (!fileMap.has("forge-std/Test.sol")) {
    fileMap.set("forge-std/Test.sol", FORGE_STD_TEST_SOL);
  }

  const sources: Record<string, { content: string }> = {};
  for (const [filePath, content] of fileMap.entries()) {
    // Compile all user sources; forge-std is resolved on demand or included
    if (!filePath.startsWith("forge-std/")) {
      sources[filePath] = { content };
    }
  }

  const input = {
    language: "Solidity",
    sources,
    settings: {
      optimizer: { enabled: true, runs: 200 },
      evmVersion: "paris",
      outputSelection: {
        "*": {
          "*": ["abi", "evm.bytecode.object", "evm.deployedBytecode.object"],
        },
      },
    },
  };

  const rawOutput = solc.compile(JSON.stringify(input), {
    import: (importPath: string) => {
      const normalized = importPath.replaceAll("\\", "/").replace(/^\.\//, "");
      if (fileMap.has(normalized)) {
        return { contents: fileMap.get(normalized)! };
      }
      // Resolve relative imports like "../src/Token.sol", "evaluation/src/Token.sol", or "./Vm.sol"
      const srcSuffix = normalized.includes("/src/") ? `src/${normalized.split("/src/").pop()}` : "";
      const testSuffix = normalized.includes("/test/") ? `test/${normalized.split("/test/").pop()}` : "";
      for (const candidate of [
        normalized.replace(/^(\.\.\/)+/, ""),
        normalized.replace(/^\.\//, "forge-std/"),
        srcSuffix,
        testSuffix,
        `src/${normalized}`,
        `test/${normalized}`,
      ]) {
        if (candidate && fileMap.has(candidate)) {
          return { contents: fileMap.get(candidate)! };
        }
      }
      return { error: `File not found in project workspace: ${importPath}` };
    },
  });

  const parsed = JSON.parse(rawOutput) as {
    errors?: SolcRawError[];
    contracts?: Record<
      string,
      Record<
        string,
        {
          abi: unknown[];
          evm?: {
            bytecode?: { object?: string };
            deployedBytecode?: { object?: string };
          };
        }
      >
    >;
  };

  const diagnostics: CompilerDiagnostic[] = [];
  let hasError = false;

  for (const err of parsed.errors ?? []) {
    if (err.severity === "error") {
      hasError = true;
    }
    const file = err.sourceLocation?.file ?? "unknown";
    const srcContent = fileMap.get(file);
    const loc =
      srcContent && err.sourceLocation && err.sourceLocation.start >= 0
        ? computeLineCol(srcContent, err.sourceLocation.start)
        : undefined;

    diagnostics.push({
      severity: err.severity,
      file,
      line: loc?.line,
      column: loc?.column,
      code: err.errorCode,
      message: err.formattedMessage || err.message,
    });
  }

  const contracts: CompiledContractArtifact[] = [];
  if (!hasError && parsed.contracts) {
    for (const [sourcePath, contractMap] of Object.entries(parsed.contracts)) {
      if (sourcePath.startsWith("forge-std/")) continue;
      for (const [contractName, artifact] of Object.entries(contractMap)) {
        const bytecode = artifact.evm?.bytecode?.object ?? "";
        const deployedBytecode = artifact.evm?.deployedBytecode?.object ?? "";
        if (!bytecode) continue; // skip interfaces and abstract contracts
        contracts.push({
          sourcePath,
          contractName,
          abi: artifact.abi ?? [],
          bytecode,
          deployedBytecode,
        });
      }
    }
  }

  return {
    compiled: !hasError,
    compilerVersion: typeof solc.version === "function" ? solc.version() : "0.8.28",
    diagnostics,
    contracts,
  };
}
