export interface AchievementMeta {
  id: string;
  title: string;
  description: string;
}

export const ACHIEVEMENT_CATALOG: Record<string, AchievementMeta> = {
  "first-verified-pass": {
    id: "first-verified-pass",
    title: "First Verified Pass",
    description: "Passed all public and hidden evaluation tests on an engineering challenge.",
  },
  "evm-token-architect": {
    id: "evm-token-architect",
    title: "Token Standard Architect",
    description: "Completed ERC-20 and ERC-721 engineering challenges with verified tests.",
  },
  "security-defender": {
    id: "security-defender",
    title: "Invariant Defender",
    description: "Identified and patched a critical smart contract vulnerability.",
  },
  "defi-protocol-builder": {
    id: "defi-protocol-builder",
    title: "DeFi Protocol Architect",
    description: "Completed Constant Product AMM and ERC-4626 Yield Vault challenges.",
  },
  "security-arena-specialist": {
    id: "security-arena-specialist",
    title: "Security Arena Specialist",
    description: "Completed 5 or more validated Security Arena missions.",
  },
  "contest-competitor": {
    id: "contest-competitor",
    title: "Contest Competitor",
    description: "Registered and scored in a timed CONSINZO engineering competition.",
  },
  "near-ts-architect": {
    id: "near-ts-architect",
    title: "NEAR TypeScript Engineer",
    description: "Completed NEAR Counter and NEAR Weighted DAO Voting challenges.",
  },
};

export function getAchievementMeta(id: string): AchievementMeta {
  return (
    ACHIEVEMENT_CATALOG[id] ?? {
      id,
      title: id,
      description: "Server-verified CONSINZO engineering milestone.",
    }
  );
}
