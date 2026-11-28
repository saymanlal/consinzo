import { z } from "zod";

export const ScoringWeightsSchema = z
  .object({
    functional_correctness: z.number().min(0).max(100),
    security_invariants: z.number().min(0).max(100),
    efficiency: z.number().min(0).max(100),
    code_quality: z.number().min(0).max(100),
  })
  .refine(
    (w) =>
      w.functional_correctness + w.security_invariants + w.efficiency + w.code_quality === 100,
    { message: "Scoring weights must sum to exactly 100" }
  );

export const HintSchema = z.object({
  order: z.number().int().min(1),
  title: z.string().min(3).max(120),
  content: z.string().min(10),
});

export const DocumentationRefSchema = z.object({
  title: z.string().min(2),
  url: z.string().url(),
  source: z.string().min(2),
  version: z.string().min(1),
  verified_at: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
});

export const ChallengeManifestSchema = z.object({
  id: z.string().regex(/^[a-z0-9-]+$/),
  slug: z.string().regex(/^[a-z0-9-]+$/),
  title: z.string().min(4).max(120),
  description: z.string().min(20).max(1000),
  ecosystem: z.enum([
    "ethereum-evm",
    "solana",
    "sui",
    "aptos",
    "starknet",
    "cardano",
    "near",
    "cosmos",
    "algorand",
    "tezos",
  ]),
  language: z.string().min(2),
  difficulty: z.enum(["beginner", "easy", "normal", "intermediate", "hard", "legend"]),
  category: z.enum([
    "programming-fundamentals",
    "smart-contract-engineering",
    "protocol-implementation",
    "defi-engineering",
    "token-standards",
    "blockchain-infrastructure",
    "advanced-blockchain-systems",
    "security-engineering",
    "cross-chain-development",
    "ecosystem-integrations",
  ]),
  tags: z.array(z.string().min(1)).min(1).max(10),
  toolchain: z.object({
    compiler: z.string().min(2),
    version: z.string().min(1),
    runner: z.string().min(2),
    evm_version: z.string().optional(),
  }),
  starter: z.object({
    entry_file: z.string().min(1),
    editable_files: z.array(z.string()).min(1),
    readonly_files: z.array(z.string()).default([]),
  }),
  tests: z.object({
    public_suite: z.string().min(1),
    hidden_suite: z.string().optional(),
    timeout_ms: z.number().int().min(1000).max(30000).default(15000),
  }),
  scoring: z.object({
    max_points: z.number().int().min(10).max(1000).default(100),
    gas_budget: z.number().int().positive().optional(),
    weights: ScoringWeightsSchema.default({
      functional_correctness: 60,
      security_invariants: 25,
      efficiency: 10,
      code_quality: 5,
    }),
  }),
  hints: z.array(HintSchema).default([]),
  solution_unlock_policy: z.enum(["after_pass", "after_3_attempts", "never_in_contest"]).default("after_pass"),
  documentation_references: z.array(DocumentationRefSchema).min(1),
  version: z.string().regex(/^\d+\.\d+\.\d+$/),
  maintainer: z.string().min(2),
  reviewer: z.string().min(2),
  publication_status: z.enum(["draft", "in_review", "published", "archived"]),
  is_security_mission: z.boolean().default(false),
});

export type ChallengeManifest = z.infer<typeof ChallengeManifestSchema>;

export interface PublicChallengeView {
  manifest: ChallengeManifest;
  readmeMarkdown: string;
  starterFiles: Array<{ path: string; content: string; readOnly: boolean }>;
  publicTests: Array<{ path: string; content: string }>;
  // Notice: hiddenTests and referenceSolution are NEVER present on PublicChallengeView
  hasHiddenTests: boolean;
}
