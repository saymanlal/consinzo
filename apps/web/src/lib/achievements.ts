export type AchievementIcon =
  | "check"
  | "coins"
  | "shield"
  | "landmark"
  | "swords"
  | "trophy"
  | "braces"
  | "star";

export interface AchievementMeta {
  id: string;
  title: string;
  description: string;
  /** Short line used in share captions: what the holder actually did. */
  feat: string;
  icon: AchievementIcon;
  /** Two CSS colours for the medallion gradient. */
  colors: [string, string];
  track: "Milestone" | "Engineering" | "Security" | "DeFi" | "Competition" | "Ecosystem";
}

export const ACHIEVEMENT_CATALOG: Record<string, AchievementMeta> = {
  "first-verified-pass": {
    id: "first-verified-pass",
    title: "First Verified Pass",
    description: "Passed all public and hidden evaluation tests on an engineering challenge.",
    feat: "passed my first smart-contract challenge against both public and hidden test suites",
    icon: "check",
    colors: ["#34d399", "#22d3ee"],
    track: "Milestone",
  },
  "evm-token-architect": {
    id: "evm-token-architect",
    title: "Token Standard Architect",
    description: "Completed ERC-20 and ERC-721 engineering challenges with verified tests.",
    feat: "implemented ERC-20 and ERC-721 from scratch and passed the verified test suites",
    icon: "coins",
    colors: ["#fbbf24", "#f97316"],
    track: "Engineering",
  },
  "security-defender": {
    id: "security-defender",
    title: "Invariant Defender",
    description: "Identified and patched a critical smart contract vulnerability.",
    feat: "found and patched a critical smart-contract vulnerability",
    icon: "shield",
    colors: ["#fb7185", "#a855f7"],
    track: "Security",
  },
  "defi-protocol-builder": {
    id: "defi-protocol-builder",
    title: "DeFi Protocol Architect",
    description: "Completed Constant Product AMM and ERC-4626 Yield Vault challenges.",
    feat: "built a constant-product AMM and an ERC-4626 vault that hold their invariants",
    icon: "landmark",
    colors: ["#22d3ee", "#6366f1"],
    track: "DeFi",
  },
  "security-arena-specialist": {
    id: "security-arena-specialist",
    title: "Security Arena Specialist",
    description: "Completed 5 or more validated Security Arena missions.",
    feat: "cleared 5+ exploit-and-patch security missions",
    icon: "swords",
    colors: ["#f43f5e", "#f59e0b"],
    track: "Security",
  },
  "contest-competitor": {
    id: "contest-competitor",
    title: "Contest Competitor",
    description: "Registered and scored in a timed CONSINZO engineering competition.",
    feat: "scored in a timed smart-contract engineering competition",
    icon: "trophy",
    colors: ["#a78bfa", "#ec4899"],
    track: "Competition",
  },
  "near-ts-architect": {
    id: "near-ts-architect",
    title: "NEAR TypeScript Engineer",
    description: "Completed NEAR Counter and NEAR Weighted DAO Voting challenges.",
    feat: "shipped NEAR smart contracts in TypeScript, including weighted DAO voting",
    icon: "braces",
    colors: ["#2dd4bf", "#84cc16"],
    track: "Ecosystem",
  },
};

export const ACHIEVEMENT_ORDER = Object.keys(ACHIEVEMENT_CATALOG);

export function getAchievementMeta(id: string): AchievementMeta {
  return (
    ACHIEVEMENT_CATALOG[id] ?? {
      id,
      title: id,
      description: "Server-verified CONSINZO engineering milestone.",
      feat: "earned a server-verified engineering milestone",
      icon: "star",
      colors: ["#a1a1aa", "#52525b"],
      track: "Milestone",
    }
  );
}
