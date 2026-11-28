/**
 * The six public difficulty tiers, in ascending order, and how each is presented.
 * Single source for filters, badges and SEO copy.
 */
export const DIFFICULTY_TIERS = [
  "beginner",
  "easy",
  "normal",
  "intermediate",
  "hard",
  "legend",
] as const;

export type DifficultyTier = (typeof DIFFICULTY_TIERS)[number];

export interface DifficultyMeta {
  id: DifficultyTier;
  label: string;
  rank: number;
  blurb: string;
  /** Badge classes for light surfaces (app pages). */
  light: string;
  /** Badge classes for dark surfaces (marketing pages). */
  dark: string;
  /** Solid dot colour. */
  dot: string;
}

export const DIFFICULTY_META: Record<DifficultyTier, DifficultyMeta> = {
  beginner: {
    id: "beginner",
    label: "Beginner",
    rank: 1,
    blurb: "First contracts: syntax, storage, and a single invariant.",
    light: "border-emerald-200 bg-emerald-50 text-emerald-800",
    dark: "border-emerald-400/30 bg-emerald-400/10 text-emerald-300",
    dot: "bg-emerald-400",
  },
  easy: {
    id: "easy",
    label: "Easy",
    rank: 2,
    blurb: "One well-known pattern with a clear specification.",
    light: "border-teal-200 bg-teal-50 text-teal-800",
    dark: "border-teal-400/30 bg-teal-400/10 text-teal-300",
    dot: "bg-teal-400",
  },
  normal: {
    id: "normal",
    label: "Normal",
    rank: 3,
    blurb: "Several interacting functions and edge cases to cover.",
    light: "border-sky-200 bg-sky-50 text-sky-800",
    dark: "border-sky-400/30 bg-sky-400/10 text-sky-300",
    dot: "bg-sky-400",
  },
  intermediate: {
    id: "intermediate",
    label: "Intermediate",
    rank: 4,
    blurb: "Standards, accounting invariants, and adversarial tests.",
    light: "border-amber-200 bg-amber-50 text-amber-800",
    dark: "border-amber-400/30 bg-amber-400/10 text-amber-300",
    dot: "bg-amber-400",
  },
  hard: {
    id: "hard",
    label: "Hard",
    rank: 5,
    blurb: "Protocol-level design where subtle bugs lose funds.",
    light: "border-rose-200 bg-rose-50 text-rose-800",
    dark: "border-rose-400/30 bg-rose-400/10 text-rose-300",
    dot: "bg-rose-400",
  },
  legend: {
    id: "legend",
    label: "Legend",
    rank: 6,
    blurb: "Multi-contract systems and exploit chains at audit depth.",
    light: "border-violet-200 bg-violet-50 text-violet-800",
    dark: "border-violet-400/30 bg-violet-400/10 text-violet-300",
    dot: "bg-violet-400",
  },
};

/** Pre-six-tier names that may still appear in stored rows. */
const LEGACY: Record<string, DifficultyTier> = { advanced: "hard", expert: "legend" };

export function normalizeDifficulty(value: string | null | undefined): DifficultyTier {
  const v = (value ?? "").toLowerCase();
  if ((DIFFICULTY_TIERS as readonly string[]).includes(v)) return v as DifficultyTier;
  return LEGACY[v] ?? "normal";
}

export function getDifficultyMeta(value: string | null | undefined): DifficultyMeta {
  return DIFFICULTY_META[normalizeDifficulty(value)];
}
