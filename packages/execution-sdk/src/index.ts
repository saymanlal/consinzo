import type { ExecutionMode, ProjectFile, SubmissionStatus } from "@consinzo/shared";

export interface CompilerDiagnostic {
  severity: "error" | "warning" | "info";
  file: string;
  line?: number;
  column?: number;
  code?: string;
  message: string;
}

export interface PublicTestResult {
  name: string;
  contract: string;
  passed: boolean;
  gasUsed?: number;
  durationMs: number;
  reason?: string;
}

export interface ExecutionRequest {
  challengeSlug: string;
  ecosystem: string;
  mode: ExecutionMode;
  files: ProjectFile[];
  includeHidden?: boolean;
  timeoutMs?: number;
}

export interface ExecutionReport {
  status: SubmissionStatus;
  mode: ExecutionMode;
  runnerName: string;
  compilerVersion: string;
  compiled: boolean;
  diagnostics: CompilerDiagnostic[];
  publicTests: PublicTestResult[];
  hiddenTestsSummary?: {
    evaluated: boolean;
    total: number;
    passed: number;
    failed: number;
    notice?: string;
  };
  totalDurationMs: number;
  averageGasUsed?: number;
  sanitizedLogs: string[];
  truncatedLogs: boolean;
}

export interface EcosystemRunner {
  readonly ecosystemId: string;
  readonly supportedModes: ExecutionMode[];
  compile(files: ProjectFile[], timeoutMs?: number): Promise<{
    compiled: boolean;
    compilerVersion: string;
    diagnostics: CompilerDiagnostic[];
    artifacts?: Record<string, unknown>;
  }>;
  runTests(
    files: ProjectFile[],
    options?: { timeoutMs?: number; includeHiddenFiles?: ProjectFile[]; mode?: ExecutionMode }
  ): Promise<ExecutionReport>;
}
