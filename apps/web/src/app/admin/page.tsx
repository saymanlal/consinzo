"use client";

import React, { useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { CheckCircle2, Plus, RotateCcw, ShieldAlert } from "lucide-react";
import { Badge, Button, Card, Input, Textarea } from "@consinzo/ui";

interface AdminAuditReport {
  id: string;
  missionSlug: string;
  authorUsername: string;
  title: string;
  severity: string;
  affectedComponent: string;
  rootCause: string;
  status: string;
  reviewerFeedback?: string;
}

interface AdminChallengeItem {
  slug: string;
  title: string;
  ecosystem: string;
  difficulty: string;
  category: string;
  version: string;
  publicationStatus: string;
  isSecurityMission: boolean;
  packageValid: boolean;
}

export default function AdminDashboardPage() {
  const queryClient = useQueryClient();
  const [feedbackById, setFeedbackById] = useState<Record<string, string>>({});
  const [reviewMsg, setReviewMsg] = useState<string | null>(null);
  const [contestSlug, setContestSlug] = useState("");
  const [contestTitle, setContestTitle] = useState("");
  const [contestDesc, setContestDesc] = useState("");
  const [contestType, setContestType] = useState<"coding" | "security" | "university" | "sponsored">(
    "security"
  );
  const [contestDurationDays, setContestDurationDays] = useState(14);
  const [contestChallenges, setContestChallenges] = useState("erc20-token-vault,constant-product-amm");
  const [contestMsg, setContestMsg] = useState<string | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["admin-overview"],
    queryFn: async () => {
      const res = await fetch("/api/v1/admin/overview");
      return { status: res.status, body: await res.json() };
    },
  });

  const { data: challengeData } = useQuery<{ challenges: AdminChallengeItem[] }>({
    queryKey: ["admin-challenges"],
    queryFn: async () => {
      const res = await fetch("/api/v1/admin/challenges");
      if (!res.ok) return { challenges: [] };
      return res.json();
    },
    enabled: data?.status === 200,
  });

  async function submitReview(reportId: string, decision: "accepted" | "needs_revision") {
    const feedback =
      feedbackById[reportId]?.trim() ||
      (decision === "accepted"
        ? "Verified root cause and remediation PoC."
        : "Please expand the PoC and remediation details.");
    setReviewMsg(null);
    const res = await fetch("/api/v1/admin/overview", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ reportId, decision, feedback }),
    });
    if (res.ok) {
      setReviewMsg(`Audit report marked ${decision}.`);
      await queryClient.invalidateQueries({ queryKey: ["admin-overview"] });
    }
  }

  async function handleCreateContest(e: React.FormEvent) {
    e.preventDefault();
    setContestMsg(null);
    const now = new Date();
    const end = new Date(now.getTime() + Math.max(1, contestDurationDays) * 24 * 60 * 60 * 1000);
    const res = await fetch("/api/v1/contests", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        slug: contestSlug.trim(),
        title: contestTitle.trim(),
        description: contestDesc.trim(),
        contestType,
        visibility: "public",
        startsAt: now.toISOString(),
        endsAt: end.toISOString(),
        challengeSlugs: contestChallenges
          .split(",")
          .map((s) => s.trim())
          .filter(Boolean),
      }),
    });
    const json = await res.json();
    if (!res.ok) {
      setContestMsg(json?.error?.message ?? "Failed to create competition.");
      return;
    }
    setContestMsg(`Competition "${json.contest.title}" created.`);
    setContestSlug("");
    setContestTitle("");
    setContestDesc("");
  }

  if (isLoading) {
    return <div className="p-8 text-xs text-zinc-500">Checking administrative authorization...</div>;
  }

  if (data?.status === 401 || data?.status === 403) {
    return (
      <div className="mx-auto max-w-xl px-4 py-16">
        <Card className="p-6 border-red-200 bg-red-50/40">
          <div className="flex items-center gap-2 text-sm font-semibold text-red-900">
            <ShieldAlert className="h-4 w-4" />
            Access Denied ({data.status})
          </div>
          <p className="mt-2 text-xs text-red-800">
            Administrative endpoints require a verified server-side role (`super_admin`,
            `platform_admin`, `challenge_manager`, or `security_reviewer`).
          </p>
        </Card>
      </div>
    );
  }

  const stats = data?.body?.stats ?? {};
  const logs = data?.body?.auditLogs ?? [];
  const reports: AdminAuditReport[] = data?.body?.auditReports ?? [];
  const challengeInventory = challengeData?.challenges ?? [];

  return (
    <div className="mx-auto max-w-[1440px] px-4 py-8 lg:px-6 space-y-6">
      <div className="border-b border-zinc-200 pb-4">
        <h1 className="text-2xl font-semibold text-zinc-950">Platform Administration</h1>
        <p className="mt-1 text-xs text-zinc-500">
          Role-restricted operations, challenge package verification, competition publishing, and
          immutable admin audit logs.
        </p>
      </div>

      {reviewMsg && (
        <div className="rounded border border-emerald-200 bg-emerald-50 px-4 py-2 text-xs text-emerald-800">
          {reviewMsg}
        </div>
      )}

      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <Card className="p-4">
          <div className="text-xs text-zinc-500">Registered Users</div>
          <div className="mt-1 font-mono text-2xl font-semibold">{stats.registeredUsers ?? 0}</div>
        </Card>
        <Card className="p-4">
          <div className="text-xs text-zinc-500">Published Challenges</div>
          <div className="mt-1 font-mono text-2xl font-semibold">
            {stats.publishedChallenges ?? 0}
          </div>
        </Card>
        <Card className="p-4">
          <div className="text-xs text-zinc-500">Total Submissions</div>
          <div className="mt-1 font-mono text-2xl font-semibold">{stats.totalSubmissions ?? 0}</div>
        </Card>
        <Card className="p-4">
          <div className="text-xs text-zinc-500">Pending Audit Reports</div>
          <div className="mt-1 font-mono text-2xl font-semibold">
            {stats.pendingAuditReports ?? 0}
          </div>
        </Card>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card className="p-5">
          <h2 className="text-sm font-semibold text-zinc-950">Security Audit Review Queue</h2>
          <div className="mt-3 space-y-3 text-xs">
            {reports.length === 0 ? (
              <p className="text-zinc-500">No audit reports in queue.</p>
            ) : (
              reports.map((r) => (
                <div key={r.id} className="rounded border border-zinc-200 p-3 space-y-2">
                  <div className="flex items-center justify-between gap-2">
                    <span className="font-semibold text-zinc-900">{r.title}</span>
                    <div className="flex items-center gap-2">
                      <Badge tone="red">{r.severity}</Badge>
                      <Badge tone={r.status === "accepted" ? "green" : "amber"}>{r.status}</Badge>
                    </div>
                  </div>
                  <div className="font-mono text-[11px] text-zinc-500">
                    @{r.authorUsername} · {r.missionSlug} · {r.affectedComponent}
                  </div>
                  <p className="text-zinc-700">{r.rootCause}</p>
                  <div className="flex flex-wrap items-center gap-2 pt-1">
                    <Input
                      placeholder="Reviewer feedback..."
                      value={feedbackById[r.id] ?? r.reviewerFeedback ?? ""}
                      onChange={(e) =>
                        setFeedbackById((prev) => ({ ...prev, [r.id]: e.target.value }))
                      }
                      className="h-8 flex-1 text-xs"
                    />
                    <Button
                      size="sm"
                      onClick={() => submitReview(r.id, "accepted")}
                      className="h-8"
                    >
                      <CheckCircle2 className="h-3.5 w-3.5" />
                      Accept
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => submitReview(r.id, "needs_revision")}
                      className="h-8"
                    >
                      <RotateCcw className="h-3.5 w-3.5" />
                      Revise
                    </Button>
                  </div>
                </div>
              ))
            )}
          </div>
        </Card>

        <Card className="p-5 space-y-4">
          <h2 className="text-sm font-semibold text-zinc-950">Create Competition</h2>
          <form onSubmit={handleCreateContest} className="space-y-3 text-xs">
            <div className="grid gap-3 sm:grid-cols-2">
              <Input
                required
                value={contestSlug}
                onChange={(e) => setContestSlug(e.target.value)}
                placeholder="slug (e.g. defi-audit-cup)"
              />
              <Input
                required
                value={contestTitle}
                onChange={(e) => setContestTitle(e.target.value)}
                placeholder="Competition Title"
              />
            </div>
            <Textarea
              required
              rows={2}
              value={contestDesc}
              onChange={(e) => setContestDesc(e.target.value)}
              placeholder="Competition rules & scope..."
            />
            <div className="grid gap-3 sm:grid-cols-2">
              <select
                value={contestType}
                onChange={(e) =>
                  setContestType(
                    e.target.value as "coding" | "security" | "university" | "sponsored"
                  )
                }
                className="h-9 rounded-md border border-zinc-300 bg-white px-3 text-xs text-zinc-800"
              >
                <option value="security">Type: Security</option>
                <option value="coding">Type: Coding</option>
                <option value="university">Type: University</option>
                <option value="sponsored">Type: Sponsored</option>
              </select>
              <Input
                type="number"
                min={1}
                max={90}
                value={contestDurationDays}
                onChange={(e) => setContestDurationDays(Number(e.target.value) || 14)}
                placeholder="Duration (days)"
              />
            </div>
            <Input
              required
              value={contestChallenges}
              onChange={(e) => setContestChallenges(e.target.value)}
              placeholder="Comma-separated challenge slugs"
            />
            {contestMsg && <p className="text-emerald-700 font-medium">{contestMsg}</p>}
            <Button type="submit" size="sm">
              <Plus className="h-3.5 w-3.5" />
              Publish Competition
            </Button>
          </form>

          <div className="border-t border-zinc-100 pt-4">
            <h3 className="text-xs font-semibold uppercase tracking-wider text-zinc-500">
              Admin Audit Logs
            </h3>
            <div className="mt-2 space-y-1.5 text-xs font-mono max-h-48 overflow-y-auto">
              {logs.length === 0 ? (
                <p className="font-sans text-zinc-500">No administrative actions recorded yet.</p>
              ) : (
                logs.map((l: { id: string; action: string; targetId: string; createdAt: string }) => (
                  <div key={l.id} className="rounded border border-zinc-200 p-2">
                    {l.createdAt} — {l.action} ({l.targetId})
                  </div>
                ))
              )}
            </div>
          </div>
        </Card>
      </div>

      <Card className="p-5">
        <h2 className="text-sm font-semibold text-zinc-950">
          Challenge Package Validation Registry ({challengeInventory.length})
        </h2>
        <div className="mt-3 overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-zinc-200 text-zinc-500">
              <tr>
                <th className="py-2 pr-4">Slug</th>
                <th className="py-2 pr-4">Title</th>
                <th className="py-2 pr-4">Ecosystem</th>
                <th className="py-2 pr-4">Category</th>
                <th className="py-2 pr-4">Type</th>
                <th className="py-2">Package Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-100">
              {challengeInventory.map((c) => (
                <tr key={c.slug}>
                  <td className="py-2 pr-4 font-mono text-zinc-900">{c.slug}</td>
                  <td className="py-2 pr-4 text-zinc-800">{c.title}</td>
                  <td className="py-2 pr-4">
                    <Badge tone="neutral">{c.ecosystem}</Badge>
                  </td>
                  <td className="py-2 pr-4 font-mono text-zinc-500">{c.category}</td>
                  <td className="py-2 pr-4">
                    <Badge tone={c.isSecurityMission ? "red" : "blue"}>
                      {c.isSecurityMission ? "Security" : "Engineering"}
                    </Badge>
                  </td>
                  <td className="py-2">
                    <Badge tone={c.packageValid ? "green" : "red"}>
                      {c.packageValid ? `Valid v${c.version}` : "Invalid"}
                    </Badge>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  );
}
