"use client";

import React from "react";
import { useQuery } from "@tanstack/react-query";
import { ShieldAlert } from "lucide-react";
import { Badge, Card } from "@consinzo/ui";

export default function AdminDashboardPage() {
  const { data, isLoading } = useQuery({
    queryKey: ["admin-overview"],
    queryFn: async () => {
      const res = await fetch("/api/v1/admin/overview");
      return { status: res.status, body: await res.json() };
    },
  });

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
  const reports = data?.body?.auditReports ?? [];

  return (
    <div className="mx-auto max-w-[1440px] px-4 py-8 lg:px-6 space-y-6">
      <div className="border-b border-zinc-200 pb-4">
        <h1 className="text-2xl font-semibold text-zinc-950">Platform Administration</h1>
        <p className="mt-1 text-xs text-zinc-500">
          Role-restricted operations, security review queue, and immutable admin audit logs.
        </p>
      </div>

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
          <div className="mt-3 space-y-2 text-xs">
            {reports.length === 0 ? (
              <p className="text-zinc-500">No audit reports in queue.</p>
            ) : (
              reports.map((r: { id: string; title: string; severity: string; status: string }) => (
                <div key={r.id} className="flex items-center justify-between rounded border border-zinc-200 p-2.5">
                  <span className="font-medium text-zinc-900">{r.title}</span>
                  <div className="flex items-center gap-2">
                    <Badge tone="red">{r.severity}</Badge>
                    <Badge tone="amber">{r.status}</Badge>
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
