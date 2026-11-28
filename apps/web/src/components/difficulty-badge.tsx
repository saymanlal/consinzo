import React from "react";
import { getDifficultyMeta } from "@/lib/difficulty";

export function DifficultyBadge({
  difficulty,
  surface = "light",
  className = "",
}: {
  difficulty: string;
  surface?: "light" | "dark";
  className?: string;
}) {
  const meta = getDifficultyMeta(difficulty);
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded border px-2 py-0.5 text-xs font-medium ${
        surface === "dark" ? meta.dark : meta.light
      } ${className}`}
    >
      <span className={`h-1.5 w-1.5 rounded-full ${meta.dot}`} aria-hidden />
      {meta.label}
    </span>
  );
}
