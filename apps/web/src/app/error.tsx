"use client";

import React from "react";
import Link from "next/link";

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div className="mx-auto flex max-w-2xl flex-col items-start justify-center px-6 py-24">
      <p className="font-mono text-xs uppercase tracking-wider text-red-700">Runtime Error</p>
      <h1 className="mt-2 text-2xl font-semibold text-zinc-950">Something went wrong</h1>
      <p className="mt-2 text-sm text-zinc-600">{error.message || "Unexpected application error."}</p>
      <div className="mt-6 flex gap-3">
        <button
          type="button"
          onClick={reset}
          className="rounded-md bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800 cursor-pointer"
        >
          Retry
        </button>
        <Link
          href="/"
          className="rounded-md border border-zinc-300 bg-white px-4 py-2 text-sm font-medium text-zinc-900"
        >
          Overview
        </Link>
      </div>
    </div>
  );
}
