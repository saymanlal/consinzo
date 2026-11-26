"use client";

import React, { useState } from "react";
import Link from "next/link";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { AlertTriangle, Code2, FileWarning, Shield } from "lucide-react";
import { Badge, Button, Card, Input, Textarea } from "@consinzo/ui";

interface ChallengeSummary {
  slug: string;
  title: string;
  description: string;
  difficulty: string;
  tags: string[];
  scoring: { max_points: number };
}

interface AuditReport {
  id: string;
  missionSlug: string;
  title: string;
  severity: string;
  affectedComponent: string;
  status: string;
  reviewerFeedback?: string;
  createdAt: string;
}

export default function SecurityArenaPage() {
  const queryClient = useQueryClient();
  const [missionSlug, setMissionSlug] = useState("reentrancy-vault-defense");
  const [title, setTitle] = useState("");
  const [severity, setSeverity] = useState("high");
  const [affectedComponent, setAffectedComponent] = useState("");
  const [rootCause, setRootCause] = useState("");
  const [attackScenario, setAttackScenario] = useState("");
  const [impact, setImpact] = useState("");
  const [proofOfConcept, setProofOfConcept] = useState("");
  const [recommendedRemediation, setRecommendedRemediation] = useState("");
  const [submitMsg, setSubmitMsg] = useState<string | null>(null);
  const [submitErr, setSubmitErr] = useState<string | null>(null);

  const { data: missionsData } = useQuery<{ challenges: ChallengeSummary[] }>({
    queryKey: ["security-missions"],
    queryFn: async () => {
      const res = await fetch("/api/v1/challenges?security=true");
      return res.json();
    },
  });

  const { data: reportsData } = useQuery<{ reports: AuditReport[] }>({
    queryKey: ["audit-reports"],
    queryFn: async () => {
      const res = await fetch("/api/v1/security/audit-reports");
      return res.json();
    },
  });

  async function handleAuditSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitErr(null);
    setSubmitMsg(null);
    const res = await fetch("/api/v1/security/audit-reports", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        missionSlug,
        title,
        severity,
        affectedComponent,
        rootCause,
        attackScenario,
        impact,
        proofOfConcept,
        recommendedRemediation,
      }),
    });
    const json = await res.json();
    if (!res.ok) {
      setSubmitErr(json?.error?.message ?? "Failed to submit audit finding (ensure you are signed in).");
      return;
    }
    setSubmitMsg("Audit finding submitted to the security review queue.");
    setTitle("");
    setAffectedComponent("");
    setRootCause("");
    setAttackScenario("");
    setImpact("");
    setProofOfConcept("");
    setRecommendedRemediation("");
    await queryClient.invalidateQueries({ queryKey: ["audit-reports"] });
  }

  const missions = missionsData?.challenges ?? [];
  const reports = reportsData?.reports ?? [];

  return (
    <div className="mx-auto max-w-[1440px] px-4 py-8 lg:px-6 space-y-8">
      <div className="border-b border-zinc-200 pb-6">
        <div className="inline-flex items-center gap-1.5 text-xs font-mono uppercase tracking-wider text-red-700">
          <Shield className="h-4 w-4" />
          Security Arena
        </div>
        <h1 className="mt-2 text-2xl font-semibold text-zinc-950">
          Exploit Defense & Smart Contract Auditing
        </h1>
        <p className="mt-1 text-sm text-zinc-600 max-w-3xl">
          Reproduce real vulnerability classes, patch vulnerable contracts against adversarial EVM
          tests, and submit structured audit findings for human security review.
        </p>
        <div className="mt-4 flex items-start gap-2 rounded-md border border-amber-200 bg-amber-50 p-3 text-xs text-amber-900 max-w-3xl">
          <AlertTriangle className="h-4 w-4 shrink-0 mt-0.5" />
          <span>
            Automated test suites validate known exploit vectors only and are never equivalent to a
            comprehensive professional security audit.
          </span>
        </div>
      </div>

      <section>
        <h2 className="text-base font-semibold text-zinc-950">Active Security Missions</h2>
        <div className="mt-3 grid gap-4 md:grid-cols-3">
          {missions.map((m) => (
            <Card key={m.slug} className="p-5 flex flex-col justify-between">
              <div>
                <div className="flex items-center justify-between">
                  <Badge tone="red">Security Mission</Badge>
                  <Badge tone="amber">{m.difficulty}</Badge>
                </div>
                <h3 className="mt-3 text-base font-semibold text-zinc-950">{m.title}</h3>
                <p className="mt-1.5 text-xs text-zinc-600">{m.description}</p>
              </div>
              <div className="mt-4 flex items-center justify-between border-t border-zinc-100 pt-3">
                <span className="font-mono text-xs text-zinc-500">{m.scoring.max_points} pts</span>
                <Link
                  href={`/workspace/${m.slug}`}
                  className="inline-flex items-center gap-1 rounded bg-slate-900 px-3 py-1.5 text-xs font-medium text-white hover:bg-slate-800"
                >
                  <Code2 className="h-3.5 w-3.5" />
                  Launch Mission
                </Link>
              </div>
            </Card>
          ))}
        </div>
      </section>

      <section className="grid gap-6 lg:grid-cols-5">
        <Card className="lg:col-span-3 p-6">
          <div className="flex items-center gap-2 text-sm font-semibold text-zinc-950">
            <FileWarning className="h-4 w-4 text-zinc-700" />
            Submit Structured Audit Finding
          </div>
          <form onSubmit={handleAuditSubmit} className="mt-4 space-y-3 text-xs">
            <div className="grid gap-3 sm:grid-cols-2">
              <div>
                <label className="block font-medium text-zinc-700 mb-1">Mission</label>
                <select
                  value={missionSlug}
                  onChange={(e) => setMissionSlug(e.target.value)}
                  className="h-9 w-full rounded-md border border-zinc-300 bg-white px-3 text-sm"
                >
                  {missions.map((m) => (
                    <option key={m.slug} value={m.slug}>
                      {m.title}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block font-medium text-zinc-700 mb-1">Severity</label>
                <select
                  value={severity}
                  onChange={(e) => setSeverity(e.target.value)}
                  className="h-9 w-full rounded-md border border-zinc-300 bg-white px-3 text-sm"
                >
                  <option value="critical">Critical</option>
                  <option value="high">High</option>
                  <option value="medium">Medium</option>
                  <option value="low">Low</option>
                  <option value="informational">Informational</option>
                </select>
              </div>
            </div>

            <div className="grid gap-3 sm:grid-cols-2">
              <div>
                <label className="block font-medium text-zinc-700 mb-1">Finding Title</label>
                <Input
                  required
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="State update after external ETH call in withdraw()"
                />
              </div>
              <div>
                <label className="block font-medium text-zinc-700 mb-1">Affected Component</label>
                <Input
                  required
                  value={affectedComponent}
                  onChange={(e) => setAffectedComponent(e.target.value)}
                  placeholder="VulnerableVault.sol:withdraw()"
                />
              </div>
            </div>

            <div>
              <label className="block font-medium text-zinc-700 mb-1">Root Cause (min 20 chars)</label>
              <Textarea
                required
                rows={2}
                value={rootCause}
                onChange={(e) => setRootCause(e.target.value)}
                placeholder="Describe the flawed invariant or ordering..."
              />
            </div>

            <div className="grid gap-3 sm:grid-cols-2">
              <div>
                <label className="block font-medium text-zinc-700 mb-1">Attack Scenario</label>
                <Textarea
                  required
                  rows={2}
                  value={attackScenario}
                  onChange={(e) => setAttackScenario(e.target.value)}
                  placeholder="Step-by-step attacker sequence..."
                />
              </div>
              <div>
                <label className="block font-medium text-zinc-700 mb-1">Impact</label>
                <Textarea
                  required
                  rows={2}
                  value={impact}
                  onChange={(e) => setImpact(e.target.value)}
                  placeholder="Quantify fund loss or privilege escalation..."
                />
              </div>
            </div>

            <div>
              <label className="block font-medium text-zinc-700 mb-1">Proof of Concept</label>
              <Textarea
                required
                rows={3}
                className="font-mono text-xs"
                value={proofOfConcept}
                onChange={(e) => setProofOfConcept(e.target.value)}
                placeholder="Foundry / Solidity PoC snippet..."
              />
            </div>

            <div>
              <label className="block font-medium text-zinc-700 mb-1">Recommended Remediation</label>
              <Textarea
                required
                rows={2}
                value={recommendedRemediation}
                onChange={(e) => setRecommendedRemediation(e.target.value)}
                placeholder="Apply CEI pattern and ReentrancyGuard..."
              />
            </div>

            {submitErr && (
              <div className="rounded border border-red-200 bg-red-50 p-2.5 text-red-800">
                {submitErr}
              </div>
            )}
            {submitMsg && (
              <div className="rounded border border-emerald-200 bg-emerald-50 p-2.5 text-emerald-800">
                {submitMsg}
              </div>
            )}

            <Button type="submit">Submit Audit Report</Button>
          </form>
        </Card>

        <Card className="lg:col-span-2 p-6">
          <h3 className="text-sm font-semibold text-zinc-950">Your Audit Submissions</h3>
          <div className="mt-4 space-y-3">
            {reports.length === 0 ? (
              <p className="text-xs text-zinc-500">
                No audit findings submitted yet (sign in to view or submit).
              </p>
            ) : (
              reports.map((r) => (
                <div key={r.id} className="rounded border border-zinc-200 p-3 text-xs space-y-1">
                  <div className="flex items-center justify-between gap-2">
                    <span className="font-semibold text-zinc-900">{r.title}</span>
                    <Badge tone={r.status === "accepted" ? "green" : "amber"}>{r.status}</Badge>
                  </div>
                  <div className="font-mono text-[11px] text-zinc-500">
                    {r.missionSlug} · {r.severity.toUpperCase()}
                  </div>
                  {r.reviewerFeedback && (
                    <div className="mt-2 rounded bg-zinc-50 p-2 text-zinc-700">
                      Reviewer: {r.reviewerFeedback}
                    </div>
                  )}
                </div>
              ))
            )}
          </div>
        </Card>
      </section>
    </div>
  );
}
