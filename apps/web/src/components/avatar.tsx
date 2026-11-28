import React from "react";

function hash(input: string): number {
  let h = 2166136261;
  for (let i = 0; i < input.length; i++) h = Math.imul(h ^ input.charCodeAt(i), 16777619);
  return h >>> 0;
}

/** Deterministic gradient avatar with initials. No image upload or third-party request. */
export function Avatar({
  username,
  displayName,
  className = "h-20 w-20 text-2xl",
}: {
  username: string;
  displayName: string;
  className?: string;
}) {
  const h = hash(username);
  const a = h % 360;
  const b = (a + 70 + ((h >> 9) % 80)) % 360;
  const initials =
    displayName
      .replace(/[^\p{L}\p{N} ]/gu, " ")
      .trim()
      .split(/\s+/)
      .slice(0, 2)
      .map((w) => w[0]?.toUpperCase() ?? "")
      .join("") || username.slice(0, 2).toUpperCase();
  return (
    <span
      aria-hidden
      className={`grid shrink-0 place-items-center rounded-2xl font-semibold text-white ring-1 ring-white/20 ${className}`}
      style={{ background: `linear-gradient(135deg, hsl(${a} 75% 52%), hsl(${b} 80% 42%))` }}
    >
      {initials}
    </span>
  );
}
