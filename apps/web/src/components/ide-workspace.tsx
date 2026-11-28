"use client";

import React, { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { getDifficultyMeta, normalizeDifficulty } from "@/lib/difficulty";
import { GUEST_LIMITS, isGuestTier } from "@/lib/guest-limits";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import {
  AlertTriangle,
  ArrowLeft,
  Check,
  CheckCircle2,
  ChevronRight,
  Copy,
  FileCode2,
  FolderOpen,
  History,
  KeyRound,
  Lightbulb,
  Lock,
  Play,
  RotateCcw,
  Send,
  Terminal,
  XCircle,
  UserRound,
} from "lucide-react";
import type { PublicChallengeView } from "@consinzo/challenge-spec";
import { ConsinzoMonacoEditor, type EditorDiagnostic } from "@consinzo/editor";
import { Badge, Button } from "@consinzo/ui";

interface ExecutionApiResponse {
  status: string;
  runnerName: string;
  compilerVersion: string;
  compiled: boolean;
  diagnostics: EditorDiagnostic[];
  publicTests: Array<{
    name: string;
    contract: string;
    passed: boolean;
    gasUsed?: number;
    durationMs: number;
    reason?: string;
  }>;
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
  score?: number;
  maxPoints?: number;
  passed?: boolean;
  scoringBreakdown?: {
    totalScore: number;
    maxPoints: number;
    components: {
      functionalCorrectness: number;
      securityInvariants: number;
      efficiency: number;
      codeQuality: number;
    };
  };
}

export function IdeWorkspace({ challenge }: { challenge: PublicChallengeView }) {
  const { manifest, readmeMarkdown, starterFiles } = challenge;
  const storageKey = `consinzo:ws:${manifest.slug}:v1`;
  const queryClient = useQueryClient();

  const [files, setFiles] = useState<Array<{ path: string; content: string; readOnly: boolean }>>(
    starterFiles
  );
  const [activePath, setActivePath] = useState<string>(
    manifest.starter.entry_file || starterFiles[0]?.path || ""
  );
  const [leftTab, setLeftTab] = useState<"spec" | "hints" | "solution" | "history">("spec");
  const [revealedHints, setRevealedHints] = useState<number[]>([]);
  const [saveState, setSaveState] = useState<"saved" | "saving" | "error">("saved");
  const [running, setRunning] = useState<"idle" | "public" | "submit">("idle");
  const [errorBanner, setErrorBanner] = useState<string | null>(null);
  const [result, setResult] = useState<ExecutionApiResponse | null>(null);
  const [unlockedSolution, setUnlockedSolution] = useState<{
    files: Array<{ path: string; content: string }>;
    explanationMarkdown: string;
  } | null>(null);
  const [solutionError, setSolutionError] = useState<string | null>(null);
  const [submissions, setSubmissions] = useState<
    Array<{ id: string; status: string; score: number; maxPoints: number; passed: boolean; createdAt: string }>
  >([]);
  const [cliCopied, setCliCopied] = useState(false);
  const [guestRuns, setGuestRuns] = useState<{ remaining: number; limit: number } | null>(null);

  const { data: meData, isLoading: meLoading } = useQuery<{ user: { id: string } | null }>({
    queryKey: ["auth-me"],
    queryFn: async () => {
      const res = await fetch("/api/v1/auth/me");
      return res.ok ? res.json() : { user: null };
    },
  });
  const isGuest = !meLoading && !meData?.user;
  const guestLocked = isGuest && !isGuestTier(normalizeDifficulty(manifest.difficulty));
  const authHref = `/auth?mode=register&next=${encodeURIComponent(`/workspace/${manifest.slug}`)}`;

  // Restore autosaved files on mount
  useEffect(() => {
    try {
      const saved = localStorage.getItem(storageKey);
      if (saved) {
        const parsed = JSON.parse(saved) as Record<string, string>;
        setFiles((prev) =>
          prev.map((f) => (!f.readOnly && parsed[f.path] !== undefined ? { ...f, content: parsed[f.path]! } : f))
        );
      }
    } catch {
      // ignore storage errors
    }
  }, [storageKey]);

  const activeFile = useMemo(
    () => files.find((f) => f.path === activePath) ?? files[0],
    [files, activePath]
  );

  function updateActiveContent(nextContent: string) {
    if (!activeFile || activeFile.readOnly) return;
    setSaveState("saving");
    setFiles((prev) => {
      const next = prev.map((f) => (f.path === activeFile.path ? { ...f, content: nextContent } : f));
      try {
        const editableMap: Record<string, string> = {};
        for (const item of next) {
          if (!item.readOnly) editableMap[item.path] = item.content;
        }
        localStorage.setItem(storageKey, JSON.stringify(editableMap));
        setSaveState("saved");
      } catch {
        setSaveState("error");
      }
      return next;
    });
  }

  function resetStarter() {
    setFiles(starterFiles);
    setResult(null);
    setErrorBanner(null);
    try {
      localStorage.removeItem(storageKey);
      setSaveState("saved");
    } catch {
      // ignore
    }
  }

  async function runPublicTests() {
    setRunning("public");
    setErrorBanner(null);
    try {
      const res = await fetch("/api/v1/execution/compile", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          challengeSlug: manifest.slug,
          mode: "local-cli",
          files: files.map((f) => ({ path: f.path, content: f.content })),
        }),
      });
      const json = await res.json();
      if (!res.ok) {
        setErrorBanner(json?.error?.message ?? "Compilation failed.");
        if (json?.error?.code === "GUEST_LIMIT_REACHED") {
          setGuestRuns({ remaining: 0, limit: json.error.details?.limit ?? GUEST_LIMITS.RUNS_PER_HOUR });
        }
        return;
      }
      if (json?.access?.guest) {
        setGuestRuns({ remaining: json.access.remaining, limit: json.access.limit });
      }
      setResult(json as ExecutionApiResponse);
    } catch {
      setErrorBanner("Network failure contacting evaluation runner.");
    } finally {
      setRunning("idle");
    }
  }

  async function submitSolution() {
    setRunning("submit");
    setErrorBanner(null);
    try {
      const res = await fetch("/api/v1/submissions", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          challengeSlug: manifest.slug,
          mode: "local-cli",
          files: files.map((f) => ({ path: f.path, content: f.content })),
        }),
      });
      const json = await res.json();
      if (!res.ok) {
        if (res.status === 401) {
          setErrorBanner("Sign in required to submit for verified scoring and hidden evaluation.");
        } else {
          setErrorBanner(json?.error?.message ?? "Submission failed.");
        }
        return;
      }

      const sub = json.submission;
      setResult({
        status: sub.status,
        runnerName: sub.runnerName,
        compilerVersion: sub.compilerVersion,
        compiled: sub.compiled,
        diagnostics: sub.diagnostics ?? [],
        publicTests: sub.publicTests,
        hiddenTestsSummary: sub.hiddenSummary,
        totalDurationMs: sub.durationMs,
        averageGasUsed: sub.averageGasUsed,
        sanitizedLogs: sub.sanitizedLogs,
        score: sub.score,
        maxPoints: sub.maxPoints,
        passed: sub.passed,
        scoringBreakdown: sub.scoringBreakdown,
      });

      await queryClient.invalidateQueries({ queryKey: ["auth-me"] });
      void loadHistory();
    } catch {
      setErrorBanner("Network failure submitting solution.");
    } finally {
      setRunning("idle");
    }
  }

  async function loadHistory() {
    try {
      const res = await fetch(`/api/v1/submissions?challengeSlug=${manifest.slug}`);
      if (res.ok) {
        const json = await res.json();
        setSubmissions(json.submissions ?? []);
      }
    } catch {
      // ignore
    }
  }

  async function loadSolution() {
    setSolutionError(null);
    try {
      const res = await fetch(`/api/v1/challenges/${manifest.slug}/solution`);
      const json = await res.json();
      if (!res.ok) {
        setSolutionError(json?.error?.message ?? "Reference solution is locked.");
        return;
      }
      setUnlockedSolution(json);
    } catch {
      setSolutionError("Failed to check reference solution unlock status.");
    }
  }

  return (
    <div className="flex min-h-[calc(100vh-3.5rem)] flex-col bg-[#0C0E12] text-zinc-100">
      {/* Top Workspace Bar */}
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-zinc-800 bg-[#12151C] px-4 py-2">
        <div className="flex items-center gap-3">
          <Link
            href="/challenges"
            className="inline-flex items-center gap-1 rounded border border-zinc-700 bg-zinc-900 px-2.5 py-1 text-xs text-zinc-300 hover:bg-zinc-800"
          >
            <ArrowLeft className="h-3.5 w-3.5" />
            Codex
          </Link>
          <div className="flex items-center gap-2">
            <span className="text-sm font-semibold text-white">{manifest.title}</span>
            <Badge tone="blue" className="border-blue-900 bg-blue-950/60 text-blue-300">
              {manifest.ecosystem}
            </Badge>
            <span className="font-mono text-xs text-zinc-400">
              {manifest.toolchain.compiler} {manifest.toolchain.version}
            </span>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <span className="font-mono text-[11px] text-zinc-400">
            {saveState === "saving"
              ? "Saving..."
              : saveState === "error"
                ? "Autosave failed"
                : "Autosaved"}
          </span>
          <span
            title="Remote GitHub Actions evaluation disabled in free-tier local config"
            className="hidden md:inline-flex items-center gap-1 rounded border border-zinc-700 bg-zinc-900 px-2 py-1 font-mono text-[11px] text-zinc-400"
          >
            Runner:{" "}
            {manifest.ecosystem === "near"
              ? "NEAR TypeScript VM (near-sdk-js)"
              : "solc + EthereumJS EVM"}
          </span>
          <Button
            size="sm"
            variant="secondary"
            onClick={resetStarter}
            className="border-zinc-700 bg-zinc-800 text-zinc-200 hover:bg-zinc-700"
          >
            <RotateCcw className="h-3.5 w-3.5" />
            Reset
          </Button>
          <Button
            size="sm"
            variant="secondary"
            disabled={running !== "idle" || guestLocked}
            onClick={runPublicTests}
            className="border-zinc-600 bg-zinc-800 text-white hover:bg-zinc-700"
          >
            <Play className="h-3.5 w-3.5 text-emerald-400" />
            {running === "public" ? "Running..." : "Run Public Tests"}
          </Button>
          {isGuest ? (
            <Link
              href={authHref}
              className="inline-flex h-8 items-center gap-2 rounded-md border border-blue-600 bg-blue-700 px-3 text-xs font-medium text-white hover:bg-blue-600"
            >
              <Send className="h-3.5 w-3.5" />
              Sign in to submit
            </Link>
          ) : (
            <Button
              size="sm"
              disabled={running !== "idle"}
              onClick={submitSolution}
              className="bg-blue-700 border-blue-600 text-white hover:bg-blue-600"
            >
              <Send className="h-3.5 w-3.5" />
              {running === "submit" ? "Evaluating..." : "Submit & Evaluate"}
            </Button>
          )}
        </div>
      </div>

      {isGuest && (
        <div className="flex flex-wrap items-center justify-between gap-2 border-b border-cyan-900/60 bg-cyan-950/40 px-4 py-2 text-xs text-cyan-100">
          <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
            <span className="inline-flex items-center gap-1.5 rounded-full border border-cyan-700/60 px-2 py-0.5 font-mono text-[11px] uppercase tracking-wider">
              <UserRound className="h-3 w-3" />
              Guest mode
            </span>
            {guestLocked ? (
              <span>
                {getDifficultyMeta(manifest.difficulty).label} challenges need an account. You can
                read the problem and edit code; guests can run Beginner, Easy and Normal.
              </span>
            ) : (
              <span>
                Public tests only ·{" "}
                {guestRuns
                  ? `${guestRuns.remaining} of ${guestRuns.limit} runs left this hour`
                  : `${GUEST_LIMITS.RUNS_PER_HOUR} runs per hour`}{" "}
                · your code stays in this browser
              </span>
            )}
          </div>
          <Link href={authHref} className="font-semibold text-white underline underline-offset-2">
            Create a free account to submit and earn points →
          </Link>
        </div>
      )}

      {errorBanner && (
        <div className="flex items-center justify-between border-b border-red-900/60 bg-red-950/60 px-4 py-2 text-xs text-red-200">
          <div className="flex items-center gap-2">
            <AlertTriangle className="h-4 w-4 text-red-400" />
            <span>{errorBanner}</span>
          </div>
          {/sign in/i.test(errorBanner) && (
            <Link href={authHref} className="shrink-0 font-semibold underline">
              Sign In →
            </Link>
          )}
        </div>
      )}

      {/* 3-Column IDE Grid */}
      <div className="grid flex-1 grid-cols-1 lg:grid-cols-12">
        {/* LEFT PANEL: Specification, Files, Hints, Solution */}
        <aside className="lg:col-span-3 flex flex-col border-b lg:border-b-0 lg:border-r border-zinc-800 bg-[#12151C]">
          <div className="flex border-b border-zinc-800 text-xs">
            {(
              [
                ["spec", "Problem"],
                ["hints", "Hints"],
                ["solution", "Solution"],
                ["history", "History"],
              ] as const
            ).map(([key, label]) => (
              <button
                key={key}
                type="button"
                onClick={() => {
                  setLeftTab(key);
                  if (key === "solution") void loadSolution();
                  if (key === "history") void loadHistory();
                }}
                className={`flex-1 py-2.5 font-medium cursor-pointer border-b-2 ${
                  leftTab === key
                    ? "border-blue-500 text-white"
                    : "border-transparent text-zinc-400 hover:text-zinc-200"
                }`}
              >
                {label}
              </button>
            ))}
          </div>

          <div className="flex-1 overflow-y-auto p-4 text-xs leading-relaxed text-zinc-300 space-y-4">
            {leftTab === "spec" && (
              <>
                <div>
                  <h2 className="text-xs font-semibold uppercase tracking-wider text-zinc-400 mb-2">
                    Project Files
                  </h2>
                  <div className="space-y-1">
                    {files.map((f) => (
                      <button
                        key={f.path}
                        type="button"
                        onClick={() => setActivePath(f.path)}
                        className={`flex w-full items-center justify-between rounded px-2.5 py-1.5 text-left font-mono text-xs cursor-pointer ${
                          activeFile?.path === f.path
                            ? "bg-zinc-800 text-white"
                            : "text-zinc-400 hover:bg-zinc-800/50 hover:text-zinc-200"
                        }`}
                      >
                        <span className="flex items-center gap-2 truncate">
                          <FileCode2 className="h-3.5 w-3.5 shrink-0 text-blue-400" />
                          {f.path}
                        </span>
                        {f.readOnly && <Lock className="h-3 w-3 shrink-0 text-zinc-500" />}
                      </button>
                    ))}
                  </div>
                </div>

                <div className="border-t border-zinc-800 pt-4">
                  <h2 className="text-xs font-semibold uppercase tracking-wider text-zinc-400 mb-2">
                    Engineering Requirements
                  </h2>
                  <pre className="whitespace-pre-wrap font-sans text-xs leading-relaxed text-zinc-200">
                    {readmeMarkdown}
                  </pre>
                </div>

                <div className="border-t border-zinc-800 pt-4">
                  <div className="flex items-center justify-between mb-2">
                    <h2 className="text-xs font-semibold uppercase tracking-wider text-zinc-400">
                      Local CLI Command (Mode B)
                    </h2>
                    <button
                      type="button"
                      onClick={() => {
                        void navigator.clipboard?.writeText(
                          `pnpm cli -- test content/challenges/${manifest.slug}`
                        );
                        setCliCopied(true);
                        setTimeout(() => setCliCopied(false), 1800);
                      }}
                      className="inline-flex items-center gap-1 rounded border border-zinc-700 bg-zinc-900 px-2 py-0.5 font-mono text-[10px] text-zinc-300 hover:bg-zinc-800 cursor-pointer"
                    >
                      {cliCopied ? (
                        <>
                          <Check className="h-3 w-3 text-emerald-400" />
                          Copied
                        </>
                      ) : (
                        <>
                          <Copy className="h-3 w-3" />
                          Copy
                        </>
                      )}
                    </button>
                  </div>
                  <pre className="rounded border border-zinc-800 bg-zinc-950 p-2.5 font-mono text-[11px] text-zinc-300 overflow-x-auto">
                    pnpm cli -- test content/challenges/{manifest.slug}
                  </pre>
                </div>
              </>
            )}

            {leftTab === "hints" && (
              <div className="space-y-3">
                <p className="text-zinc-400">
                  Reveal progressive engineering hints one at a time.
                </p>
                {manifest.hints.length === 0 ? (
                  <p className="text-zinc-500">No hints configured for this challenge.</p>
                ) : (
                  manifest.hints.map((h) => {
                    const shown = revealedHints.includes(h.order);
                    return (
                      <div key={h.order} className="rounded border border-zinc-800 bg-zinc-900/60 p-3">
                        <div className="flex items-center justify-between">
                          <span className="flex items-center gap-1.5 font-medium text-zinc-100">
                            <Lightbulb className="h-3.5 w-3.5 text-amber-400" />
                            Hint {h.order}: {h.title}
                          </span>
                          {!shown && (
                            <button
                              type="button"
                              onClick={() => setRevealedHints((p) => [...p, h.order])}
                              className="text-blue-400 hover:underline cursor-pointer"
                            >
                              Reveal
                            </button>
                          )}
                        </div>
                        {shown && <p className="mt-2 text-zinc-300">{h.content}</p>}
                      </div>
                    );
                  })
                )}
              </div>
            )}

            {leftTab === "solution" && (
              <div className="space-y-3">
                {solutionError && (
                  <div className="rounded border border-zinc-800 bg-zinc-900 p-4 text-zinc-300">
                    <div className="flex items-center gap-2 font-medium text-white">
                      <KeyRound className="h-4 w-4 text-amber-400" />
                      Reference Solution Protected
                    </div>
                    <p className="mt-1.5 text-zinc-400">{solutionError}</p>
                  </div>
                )}
                {unlockedSolution && (
                  <div className="space-y-3">
                    <div className="rounded border border-emerald-900 bg-emerald-950/40 p-3 text-emerald-300">
                      Unlocked via verified challenge completion.
                    </div>
                    <p className="text-zinc-300 whitespace-pre-wrap">
                      {unlockedSolution.explanationMarkdown}
                    </p>
                    {unlockedSolution.files.map((sf) => (
                      <div key={sf.path}>
                        <div className="font-mono text-xs text-zinc-400 mb-1">{sf.path}</div>
                        <pre className="overflow-x-auto rounded border border-zinc-800 bg-zinc-950 p-3 font-mono text-[11px] text-zinc-200">
                          {sf.content}
                        </pre>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}

            {leftTab === "history" && (
              <div className="space-y-2">
                {submissions.length === 0 ? (
                  <div className="flex items-center gap-2 text-zinc-500">
                    <History className="h-4 w-4" />
                    No recorded submissions yet (or sign in to view).
                  </div>
                ) : (
                  submissions.map((s) => (
                    <div
                      key={s.id}
                      className="rounded border border-zinc-800 bg-zinc-900/60 p-2.5 flex items-center justify-between"
                    >
                      <div>
                        <div className="font-medium text-zinc-100">
                          {s.passed ? "PASSED" : s.status.toUpperCase()}
                        </div>
                        <div className="font-mono text-[11px] text-zinc-500">
                          {new Date(s.createdAt).toLocaleString()}
                        </div>
                      </div>
                      <div className="font-mono text-xs text-zinc-200">
                        {s.score}/{s.maxPoints}
                      </div>
                    </div>
                  ))
                )}
              </div>
            )}
          </div>
        </aside>

        {/* CENTER PANEL: Monaco Editor */}
        <section className="lg:col-span-6 flex flex-col border-b lg:border-b-0 lg:border-r border-zinc-800 min-h-[460px]">
          <div className="flex items-center gap-1 overflow-x-auto border-b border-zinc-800 bg-[#12151C] px-2 pt-1.5">
            {files.map((f) => (
              <button
                key={f.path}
                type="button"
                onClick={() => setActivePath(f.path)}
                className={`inline-flex items-center gap-1.5 rounded-t border-t border-x px-3 py-1.5 font-mono text-xs cursor-pointer ${
                  activeFile?.path === f.path
                    ? "border-zinc-700 bg-[#0C0E12] text-white"
                    : "border-transparent bg-transparent text-zinc-400 hover:text-zinc-200"
                }`}
              >
                <FolderOpen className="h-3 w-3 text-zinc-500" />
                {f.path}
                {f.readOnly && <span className="text-[10px] text-zinc-500">(ro)</span>}
              </button>
            ))}
          </div>

          <div className="flex-1 min-h-[380px]">
            {activeFile && (
              <ConsinzoMonacoEditor
                filePath={activeFile.path}
                value={activeFile.content}
                readOnly={activeFile.readOnly}
                diagnostics={result?.diagnostics ?? []}
                onChange={updateActiveContent}
                onSave={runPublicTests}
              />
            )}
          </div>

          {/* BOTTOM TERMINAL / LOGS PANEL */}
          <div className="h-48 border-t border-zinc-800 bg-[#090B0E] flex flex-col">
            <div className="flex items-center justify-between border-b border-zinc-800 px-3 py-1.5 text-[11px] font-mono text-zinc-400">
              <span className="flex items-center gap-1.5">
                <Terminal className="h-3.5 w-3.5 text-zinc-400" />
                {manifest.ecosystem === "near"
                  ? "Compiler & NEAR VM Execution Logs"
                  : "Compiler & EVM Execution Logs"}
              </span>
              {result && (
                <span>
                  {result.compilerVersion.split("+")[0]} · {result.totalDurationMs}ms
                  {result.averageGasUsed ? ` · avg ${result.averageGasUsed.toLocaleString()} gas` : ""}
                </span>
              )}
            </div>
            <div className="flex-1 overflow-y-auto p-3 font-mono text-xs space-y-1">
              {!result ? (
                <div className="text-zinc-500">
                  {manifest.ecosystem === "near"
                    ? 'Ready. Press "Run Public Tests" (or Cmd/Ctrl+S) to typecheck TypeScript and execute in the NEAR VM.'
                    : 'Ready. Press "Run Public Tests" (or Cmd/Ctrl+S) to compile with solc 0.8.28 and execute in EVM.'}
                </div>
              ) : (
                result.sanitizedLogs.map((line, i) => (
                  <div
                    key={i}
                    className={
                      line.includes("[FAIL]") || line.includes("[error]")
                        ? "text-red-400"
                        : line.includes("[PASS]")
                          ? "text-emerald-400"
                          : "text-zinc-300"
                    }
                  >
                    {line}
                  </div>
                ))
              )}
            </div>
          </div>
        </section>

        {/* RIGHT PANEL: Public Tests & Evaluation Summary */}
        <aside className="lg:col-span-3 flex flex-col bg-[#12151C] p-4 space-y-4 overflow-y-auto">
          <div>
            <h2 className="text-xs font-semibold uppercase tracking-wider text-zinc-400">
              Evaluation Status
            </h2>
            {!result ? (
              <div className="mt-2 rounded border border-zinc-800 bg-zinc-900/50 p-3 text-xs text-zinc-400">
                No test run yet.
              </div>
            ) : (
              <div className="mt-2 rounded border border-zinc-800 bg-zinc-900/70 p-3 space-y-2">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-medium text-zinc-300">Outcome</span>
                  <Badge
                    tone={result.status === "passed" ? "green" : "red"}
                    className={
                      result.status === "passed"
                        ? "border-emerald-800 bg-emerald-950 text-emerald-300"
                        : "border-red-800 bg-red-950 text-red-300"
                    }
                  >
                    {result.status.toUpperCase()}
                  </Badge>
                </div>
                {typeof result.score === "number" && (
                  <div className="flex items-center justify-between text-xs">
                    <span className="text-zinc-400">Verified Score</span>
                    <span className="font-mono font-semibold text-white">
                      {result.score} / {result.maxPoints}
                    </span>
                  </div>
                )}
                {result.scoringBreakdown?.components && (
                  <div className="grid grid-cols-2 gap-1.5 border-t border-zinc-800 pt-2 font-mono text-[10px]">
                    <div className="flex justify-between rounded bg-zinc-950/60 px-2 py-1 text-zinc-300">
                      <span className="text-zinc-500">Func</span>
                      <span>{result.scoringBreakdown.components.functionalCorrectness}</span>
                    </div>
                    <div className="flex justify-between rounded bg-zinc-950/60 px-2 py-1 text-zinc-300">
                      <span className="text-zinc-500">Sec</span>
                      <span>{result.scoringBreakdown.components.securityInvariants}</span>
                    </div>
                    <div className="flex justify-between rounded bg-zinc-950/60 px-2 py-1 text-zinc-300">
                      <span className="text-zinc-500">Eff</span>
                      <span>{result.scoringBreakdown.components.efficiency}</span>
                    </div>
                    <div className="flex justify-between rounded bg-zinc-950/60 px-2 py-1 text-zinc-300">
                      <span className="text-zinc-500">Qual</span>
                      <span>{result.scoringBreakdown.components.codeQuality}</span>
                    </div>
                  </div>
                )}
                {result.hiddenTestsSummary && (
                  <div className="border-t border-zinc-800 pt-2 text-[11px] text-zinc-400">
                    <div className="flex items-center justify-between">
                      <span className="flex items-center gap-1">
                        <Lock className="h-3 w-3" />
                        Hidden Suite
                      </span>
                      <span className="font-mono text-zinc-200">
                        {result.hiddenTestsSummary.evaluated
                          ? `${result.hiddenTestsSummary.passed}/${result.hiddenTestsSummary.total} passed`
                          : "Not evaluated"}
                      </span>
                    </div>
                    {result.hiddenTestsSummary.notice && (
                      <p className="mt-1 text-zinc-500">{result.hiddenTestsSummary.notice}</p>
                    )}
                  </div>
                )}
              </div>
            )}
          </div>

          <div>
            <h2 className="text-xs font-semibold uppercase tracking-wider text-zinc-400">
              Public Test Cases
            </h2>
            <div className="mt-2 space-y-2">
              {!result ? (
                <div className="text-xs text-zinc-500">
                  Run tests to inspect per-function pass/fail and gas metrics.
                </div>
              ) : result.publicTests.length === 0 ? (
                <div className="text-xs text-red-400">
                  Compilation failed — fix compiler errors in logs to execute tests.
                </div>
              ) : (
                result.publicTests.map((t) => (
                  <div
                    key={`${t.contract}.${t.name}`}
                    className="rounded border border-zinc-800 bg-zinc-900/50 p-2.5 text-xs"
                  >
                    <div className="flex items-center justify-between gap-2">
                      <span className="flex items-center gap-1.5 font-mono text-zinc-200 truncate">
                        {t.passed ? (
                          <CheckCircle2 className="h-3.5 w-3.5 shrink-0 text-emerald-400" />
                        ) : (
                          <XCircle className="h-3.5 w-3.5 shrink-0 text-red-400" />
                        )}
                        {t.name}()
                      </span>
                      {typeof t.gasUsed === "number" && (
                        <span className="font-mono text-[11px] text-zinc-400 shrink-0">
                          {t.gasUsed.toLocaleString()} gas
                        </span>
                      )}
                    </div>
                    {t.reason && (
                      <div className="mt-1.5 font-mono text-[11px] text-red-300 break-words">
                        <ChevronRight className="inline h-3 w-3" /> {t.reason}
                      </div>
                    )}
                  </div>
                ))
              )}
            </div>
          </div>
        </aside>
      </div>
    </div>
  );
}
