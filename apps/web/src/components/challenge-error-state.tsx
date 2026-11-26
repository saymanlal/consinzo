"use client";

import React from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { AlertTriangle, RefreshCw } from "lucide-react";
import { Button, Card } from "@consinzo/ui";

export function ChallengeErrorState({
  title,
  message,
  recoverable = false,
  code,
}: {
  title: string;
  message: string;
  recoverable?: boolean;
  code: string;
}) {
  const router = useRouter();

  return (
    <div className="mx-auto max-w-2xl px-4 py-16">
      <Card className="border-amber-200 bg-amber-50/40 p-6 space-y-4">
        <div className="flex items-center gap-2 font-mono text-xs uppercase tracking-wider text-amber-900">
          <AlertTriangle className="h-4 w-4" />
          {code}
        </div>
        <h1 className="text-xl font-semibold text-zinc-950">{title}</h1>
        <p className="text-sm text-zinc-700">{message}</p>
        <div className="flex flex-wrap gap-3 pt-2">
          {recoverable && (
            <Button onClick={() => router.refresh()}>
              <RefreshCw className="h-3.5 w-3.5" />
              Retry Loading
            </Button>
          )}
          <Link
            href="/challenges"
            className="inline-flex items-center rounded-md border border-zinc-300 bg-white px-4 py-2 text-xs font-medium text-zinc-900 hover:bg-zinc-50"
          >
            Back to Codex Catalogue
          </Link>
        </div>
      </Card>
    </div>
  );
}
