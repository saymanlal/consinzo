"use client";

import React, { useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { CheckCircle2, RotateCcw, ShieldAlert } from "lucide-react";
import { Badge, Button, Card, Input } from "@consinzo/ui";

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

export default function AdminDashboardPage() {
  const queryClient = useQueryClient();
  const [feedbackById, setFeedbackById] = useState<Record<string, string>>({});
  const [reviewMsg, setReviewMsg] = useState<string | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["admin-overview"],
    queryFn: async () => {
      const res = await fetch("/api/v1/admin/overview");
      return { status: res.status, body: await res.json() };
    },
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

  return (
    <div className="mx-auto max-w-[1440px] px-4 py-8 lg:px-6 space-y-6">
      <div className="border-b border-zinc-200 pb-4">
        <h1 className="text-2xl font-semibold text-zinc-950">Platform Administration</h1>
        <p className="mt-1 text-xs text-zinc-500">
          Role-restricted operations, security review queue, and immutable admin audit logs.
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

        <Card className="p-5">
          <h2 className="text-sm font-semibold text-zinc-950">Admin Audit Logs</h2>
          <div className="mt-3 space-y-2 text-xs font-mono">
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
        </Card>
      </div>
    </div>
  );
}
