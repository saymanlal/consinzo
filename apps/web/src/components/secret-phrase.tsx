"use client";

import React, { useEffect, useState } from "react";
import { Check, Copy, Eye, EyeOff } from "lucide-react";

/**
 * Shows a recovery phrase as a numbered grid that is blurred until the user chooses to
 * reveal it, and hides itself again after a short while.
 */
export function SecretPhrase({
  mnemonic,
  autoHideSeconds = 60,
  surface = "dark",
}: {
  mnemonic: string;
  autoHideSeconds?: number;
  surface?: "dark" | "light";
}) {
  const [revealed, setRevealed] = useState(false);
  const [copied, setCopied] = useState(false);
  const words = mnemonic.split(" ");
  const dark = surface === "dark";

  useEffect(() => {
    if (!revealed) return;
    const t = setTimeout(() => setRevealed(false), autoHideSeconds * 1000);
    return () => clearTimeout(t);
  }, [revealed, autoHideSeconds]);

  async function copy() {
    try {
      await navigator.clipboard.writeText(mnemonic);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      /* clipboard unavailable: the user can still write the words down */
    }
  }

  const btn = dark
    ? "border-white/15 text-zinc-200 hover:bg-white/10"
    : "border-zinc-300 text-zinc-700 hover:bg-zinc-50";

  return (
    <div>
      <ol
        aria-label="Recovery phrase"
        aria-hidden={!revealed}
        className={`grid grid-cols-2 gap-2 rounded-xl border p-3 font-mono text-sm transition sm:grid-cols-3 ${
          dark ? "border-white/10 bg-black/40" : "border-zinc-200 bg-zinc-50"
        } ${revealed ? "" : "pointer-events-none select-none blur-[7px]"}`}
      >
        {words.map((w, i) => (
          <li
            key={i}
            className={`flex items-baseline gap-2 rounded-md px-2 py-1.5 ${dark ? "bg-white/5 text-white" : "bg-white text-zinc-900"}`}
          >
            <span className={`w-5 text-right text-[10px] ${dark ? "text-zinc-500" : "text-zinc-400"}`}>
              {i + 1}
            </span>
            {revealed ? w : "•••••"}
          </li>
        ))}
      </ol>
      <div className="mt-3 flex flex-wrap gap-2">
        <button
          type="button"
          onClick={() => setRevealed((r) => !r)}
          aria-pressed={revealed}
          className={`inline-flex cursor-pointer items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-medium ${btn}`}
        >
          {revealed ? <EyeOff className="h-3.5 w-3.5" /> : <Eye className="h-3.5 w-3.5" />}
          {revealed ? "Hide" : "Reveal phrase"}
        </button>
        <button
          type="button"
          onClick={copy}
          className={`inline-flex cursor-pointer items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-medium ${btn}`}
        >
          {copied ? <Check className="h-3.5 w-3.5" /> : <Copy className="h-3.5 w-3.5" />}
          {copied ? "Copied" : "Copy"}
        </button>
      </div>
      <p className={`mt-2 text-[11px] ${dark ? "text-zinc-500" : "text-zinc-500"}`}>
        Make sure nobody can see your screen. The phrase hides again after {autoHideSeconds}{" "}
        seconds.
      </p>
    </div>
  );
}
