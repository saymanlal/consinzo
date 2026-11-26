export interface KnowledgeEntry {
  slug: string;
  ecosystemId: string;
  entryType: "language" | "compiler" | "sdk" | "standard" | "protocol" | "tool";
  title: string;
  summary: string;
  source: string;
  sourceUrl: string;
  applicableVersion: string;
  lastVerifiedAt: string;
  reviewStatus: "verified" | "needs_update";
}

export interface ProtocolLabSpec {
  slug: string;
  title: string;
  category: string;
  summary: string;
  architectureSteps: string[];
  invariants: string[];
  linkedChallengeSlug?: string;
}

export interface LearningPathSpec {
  slug: string;
  title: string;
  ecosystemId: string;
  difficulty: string;
  description: string;
  challengeSlugs: string[];
}

export const KNOWLEDGE_ENTRIES: readonly KnowledgeEntry[] = [
  {
    slug: "solidity-08-overflow-checks",
    ecosystemId: "ethereum-evm",
    entryType: "language",
    title: "Solidity 0.8.x Checked Arithmetic & Unchecked Blocks",
    summary:
      "Built-in arithmetic overflow/underflow checks revert with Panic(0x11) unless explicitly wrapped in unchecked{} after invariant guards.",
    source: "Solidity Language Documentation",
    sourceUrl: "https://docs.soliditylang.org/en/v0.8.28/",
    applicableVersion: "0.8.28",
    lastVerifiedAt: "2026-11-26",
    reviewStatus: "verified",
  },
  {
    slug: "eip-20-fungible-standard",
    ecosystemId: "ethereum-evm",
    entryType: "standard",
    title: "EIP-20 Token Standard & Allowance Semantics",
    summary:
      "Canonical fungible token interface covering balance accounting, transfer events, and approval race-condition awareness.",
    source: "Ethereum Improvement Proposals",
    sourceUrl: "https://eips.ethereum.org/EIPS/eip-20",
    applicableVersion: "Final",
    lastVerifiedAt: "2026-11-26",
    reviewStatus: "verified",
  },
  {
    slug: "eip-4626-vault-rounding",
    ecosystemId: "ethereum-evm",
    entryType: "standard",
    title: "EIP-4626 Tokenized Vaults & Inflation Defense",
    summary:
      "Standardized yield vault accounting rules specifying vault-favorable rounding directions and internal asset tracking.",
    source: "Ethereum Improvement Proposals",
    sourceUrl: "https://eips.ethereum.org/EIPS/eip-4626",
    applicableVersion: "Final",
    lastVerifiedAt: "2026-11-26",
    reviewStatus: "verified",
  },
  {
    slug: "foundry-forge-testing",
    ecosystemId: "ethereum-evm",
    entryType: "tool",
    title: "Foundry Forge Test Suites & HEVM Cheatcodes",
    summary:
      "Contract-based Solidity testing using vm.prank, vm.deal, vm.warp, and vm.expectRevert for deterministic state verification.",
    source: "Foundry Book",
    sourceUrl: "https://book.getfoundry.sh/",
    applicableVersion: "0.3.x",
    lastVerifiedAt: "2026-11-26",
    reviewStatus: "verified",
  },
  {
    slug: "solana-anchor-account-model",
    ecosystemId: "solana",
    entryType: "sdk",
    title: "Solana Account & PDA Ownership Model (Reference)",
    summary:
      "Program Derived Addresses (PDAs), signer validation, and rent-exempt account constraints in Anchor.",
    source: "Solana Official Docs",
    sourceUrl: "https://solana.com/docs",
    applicableVersion: "Anchor 0.30.1",
    lastVerifiedAt: "2026-11-26",
    reviewStatus: "verified",
  },
  {
    slug: "sui-object-move-model",
    ecosystemId: "sui",
    entryType: "language",
    title: "Sui Object-Centric Move Model (Reference)",
    summary:
      "Owned vs shared object capabilities in Sui Move, distinct from account-resource storage in Aptos Move.",
    source: "Sui Documentation",
    sourceUrl: "https://docs.sui.io/",
    applicableVersion: "1.37.x",
    lastVerifiedAt: "2026-11-26",
    reviewStatus: "verified",
  },
];

export const PROTOCOL_LABS: readonly ProtocolLabSpec[] = [
  {
    slug: "amm-constant-product-lab",
    title: "Constant Product AMM Mechanics",
    category: "Automated Market Makers",
    summary:
      "Explore reserve curves, LP share dilution protection, slippage bounds, and fee accumulation across x * y = k pools.",
    architectureSteps: [
      "Deposit token0 and token1 into pool reserves; mint geometric-mean LP shares.",
      "Compute swap output with 0.3% fee retention on input amount.",
      "Verify invariant reserve0 * reserve1 >= k_before after every swap.",
    ],
    invariants: [
      "k_after >= k_before on all swaps",
      "LP redemption is strictly proportional to totalShares",
    ],
    linkedChallengeSlug: "constant-product-amm",
  },
  {
    slug: "tokenized-yield-vault-lab",
    title: "ERC-4626 Yield Vaults & Donation Resistance",
    category: "Lending & Vaults",
    summary:
      "Understand share-to-asset conversion formulas, yield accrual, and first-depositor inflation attacks.",
    architectureSteps: [
      "Wrap underlying ERC-20 asset and issue ERC-4626 vault shares.",
      "Simulate external yield accrual or unsolicited token donations.",
      "Verify share pricing rounding favors vault solvency.",
    ],
    invariants: [
      "Redeeming all shares never exceeds totalManagedAssets",
      "Unsolicited donations cannot reduce subsequent depositor shares to 0",
    ],
    linkedChallengeSlug: "erc4626-tokenized-vault",
  },
  {
    slug: "timelock-governance-lab",
    title: "On-Chain Governance Timelocks",
    category: "Governance",
    summary:
      "Inspect proposal queuing, ETA delay enforcement, grace-period expiration, and multi-sig authorization.",
    architectureSteps: [
      "Hash target, value, calldata, and eta into deterministic txHash.",
      "Enforce MIN_DELAY between queue timestamp and execution window.",
      "Expire unexecuted proposals after GRACE_PERIOD.",
    ],
    invariants: [
      "No queued action executes prior to eta",
      "Executed actions cannot be replayed",
    ],
    linkedChallengeSlug: "timelock-governance",
  },
];

export const LEARNING_PATHS: readonly LearningPathSpec[] = [
  {
    slug: "evm-smart-contract-foundations",
    title: "EVM Smart Contract Foundations",
    ecosystemId: "ethereum-evm",
    difficulty: "beginner",
    description:
      "Master ERC-20, ERC-721, Merkle verification, and multi-signature treasury patterns with real Solidity compilation and EVM execution.",
    challengeSlugs: [
      "erc20-token-vault",
      "erc721-royalty-nft",
      "access-control-multisig",
      "merkle-airdrop-claim",
    ],
  },
  {
    slug: "defi-protocol-engineering",
    title: "DeFi Protocol Engineering",
    ecosystemId: "ethereum-evm",
    difficulty: "advanced",
    description:
      "Design constant-product AMMs, ERC-4626 yield vaults, and governance timelock controllers verified against protocol invariants.",
    challengeSlugs: [
      "constant-product-amm",
      "erc4626-tokenized-vault",
      "timelock-governance",
    ],
  },
  {
    slug: "smart-contract-security-track",
    title: "Smart Contract Security & Exploitation Defense",
    ecosystemId: "ethereum-evm",
    difficulty: "intermediate",
    description:
      "Reproduce and patch reentrancy, donation/inflation attacks, and ECDSA signature replay vulnerabilities.",
    challengeSlugs: [
      "reentrancy-vault-defense",
      "flash-loan-arbitrage-guard",
      "signature-replay-escrow",
    ],
  },
];
