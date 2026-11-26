export type SupportLevel = 0 | 1 | 2 | 3 | 4 | 5;

export const SUPPORT_LEVEL_LABELS: Record<SupportLevel, { name: string; description: string }> = {
  0: {
    name: "Reference Only",
    description: "Ecosystem metadata, official toolchain versions, and reference links only.",
  },
  1: {
    name: "Editor Support",
    description: "Monaco syntax highlighting and file templates; no local or remote execution.",
  },
  2: {
    name: "Compilation Support",
    description: "Verified compiler integration with diagnostic reporting.",
  },
  3: {
    name: "Execution Support",
    description: "Real contract deployment and public test suite execution.",
  },
  4: {
    name: "Automated Evaluation",
    description: "Automated scoring with server-isolated hidden evaluation tests.",
  },
  5: {
    name: "Competition-Ready",
    description: "Hardened isolation, deterministic scoring, and live contest readiness.",
  },
};

export interface ToolchainSpec {
  id: string;
  name: string;
  pinnedVersion: string;
  language: string;
  cliCommand?: string;
  verifiedAt: string;
}

export interface EcosystemCapabilities {
  editorSyntax: boolean;
  browserCompile: boolean;
  browserExecute: boolean;
  localCliCompile: boolean;
  localCliTest: boolean;
  remoteHiddenEval: boolean;
  competitionIsolated: boolean;
}

export interface EcosystemRecord {
  id:
    | "ethereum-evm"
    | "solana"
    | "sui"
    | "aptos"
    | "starknet"
    | "cardano"
    | "near"
    | "cosmos"
    | "algorand"
    | "tezos";
  name: string;
  shortName: string;
  adapterId: string;
  supportLevel: SupportLevel;
  primaryLanguages: string[];
  toolchains: ToolchainSpec[];
  capabilities: EcosystemCapabilities;
  sharedInfrastructureGroup?: string;
  architectureNotes: string;
  officialDocsUrl: string;
}

export const ECOSYSTEM_REGISTRY: readonly EcosystemRecord[] = [
  {
    id: "ethereum-evm",
    name: "Ethereum / EVM",
    shortName: "EVM",
    adapterId: "evm-foundry-solc",
    supportLevel: 4,
    primaryLanguages: ["Solidity", "Vyper", "Yul"],
    toolchains: [
      {
        id: "solc",
        name: "Solidity Compiler (solc)",
        pinnedVersion: "0.8.28",
        language: "Solidity",
        cliCommand: "solc --version",
        verifiedAt: "2026-11-26",
      },
      {
        id: "foundry",
        name: "Foundry (forge / anvil / cast)",
        pinnedVersion: "0.3.0+",
        language: "Solidity",
        cliCommand: "forge --version",
        verifiedAt: "2026-11-26",
      },
      {
        id: "ethereumjs-vm",
        name: "EthereumJS EVM (In-Process / Worker)",
        pinnedVersion: "7.x",
        language: "Solidity",
        verifiedAt: "2026-11-26",
      },
    ],
    capabilities: {
      editorSyntax: true,
      browserCompile: true,
      browserExecute: true,
      localCliCompile: true,
      localCliTest: true,
      remoteHiddenEval: true,
      competitionIsolated: false,
    },
    sharedInfrastructureGroup: "evm-compatible",
    architectureNotes:
      "Primary Phase 1 ecosystem. Compiles Solidity via official solc and executes Foundry-compatible Solidity test suites via EthereumJS EVM or native forge.",
    officialDocsUrl: "https://docs.soliditylang.org/",
  },
  {
    id: "solana",
    name: "Solana",
    shortName: "SOL",
    adapterId: "solana-anchor-adapter",
    supportLevel: 1,
    primaryLanguages: ["Rust"],
    toolchains: [
      {
        id: "anchor",
        name: "Anchor CLI",
        pinnedVersion: "0.30.1",
        language: "Rust",
        cliCommand: "anchor --version",
        verifiedAt: "2026-11-26",
      },
      {
        id: "solana-cli",
        name: "Agave / Solana CLI",
        pinnedVersion: "2.0.x",
        language: "Rust",
        cliCommand: "solana --version",
        verifiedAt: "2026-11-26",
      },
    ],
    capabilities: {
      editorSyntax: true,
      browserCompile: false,
      browserExecute: false,
      localCliCompile: false,
      localCliTest: false,
      remoteHiddenEval: false,
      competitionIsolated: false,
    },
    architectureNotes:
      "Account-based Sealevel runtime. Distinct from EVM and Move chains; runner scheduled for Phase 4.",
    officialDocsUrl: "https://solana.com/docs",
  },
  {
    id: "sui",
    name: "Sui",
    shortName: "SUI",
    adapterId: "sui-move-adapter",
    supportLevel: 0,
    primaryLanguages: ["Move"],
    toolchains: [
      {
        id: "sui-cli",
        name: "Sui CLI",
        pinnedVersion: "1.37.x",
        language: "Move",
        cliCommand: "sui --version",
        verifiedAt: "2026-11-26",
      },
    ],
    capabilities: {
      editorSyntax: false,
      browserCompile: false,
      browserExecute: false,
      localCliCompile: false,
      localCliTest: false,
      remoteHiddenEval: false,
      competitionIsolated: false,
    },
    architectureNotes:
      "Object-centric Move model (distinct adapter from Aptos Move; never shared with Aptos execution).",
    officialDocsUrl: "https://docs.sui.io/",
  },
  {
    id: "aptos",
    name: "Aptos",
    shortName: "APT",
    adapterId: "aptos-move-adapter",
    supportLevel: 0,
    primaryLanguages: ["Move"],
    toolchains: [
      {
        id: "aptos-cli",
        name: "Aptos CLI",
        pinnedVersion: "4.x",
        language: "Move",
        cliCommand: "aptos --version",
        verifiedAt: "2026-11-26",
      },
    ],
    capabilities: {
      editorSyntax: false,
      browserCompile: false,
      browserExecute: false,
      localCliCompile: false,
      localCliTest: false,
      remoteHiddenEval: false,
      competitionIsolated: false,
    },
    architectureNotes:
      "Account-resource Move model (distinct execution adapter from Sui Move).",
    officialDocsUrl: "https://aptos.dev/",
  },
  {
    id: "starknet",
    name: "Starknet",
    shortName: "STRK",
    adapterId: "starknet-cairo-adapter",
    supportLevel: 0,
    primaryLanguages: ["Cairo"],
    toolchains: [
      {
        id: "scarb",
        name: "Scarb & Starknet Foundry",
        pinnedVersion: "2.8.x",
        language: "Cairo",
        cliCommand: "scarb --version",
        verifiedAt: "2026-11-26",
      },
    ],
    capabilities: {
      editorSyntax: false,
      browserCompile: false,
      browserExecute: false,
      localCliCompile: false,
      localCliTest: false,
      remoteHiddenEval: false,
      competitionIsolated: false,
    },
    architectureNotes: "Validity-rollup Cairo VM ecosystem. Planned for Phase 4.",
    officialDocsUrl: "https://docs.starknet.io/",
  },
  {
    id: "cardano",
    name: "Cardano",
    shortName: "ADA",
    adapterId: "cardano-aiken-adapter",
    supportLevel: 0,
    primaryLanguages: ["Aiken", "Plutus"],
    toolchains: [
      {
        id: "aiken",
        name: "Aiken CLI",
        pinnedVersion: "1.1.x",
        language: "Aiken",
        cliCommand: "aiken --version",
        verifiedAt: "2026-11-26",
      },
    ],
    capabilities: {
      editorSyntax: false,
      browserCompile: false,
      browserExecute: false,
      localCliCompile: false,
      localCliTest: false,
      remoteHiddenEval: false,
      competitionIsolated: false,
    },
    architectureNotes: "Extended UTXO (eUTXO) validator model. Planned for Phase 4.",
    officialDocsUrl: "https://aiken-lang.org/",
  },
  {
    id: "near",
    name: "NEAR",
    shortName: "NEAR",
    adapterId: "near-wasm-adapter",
    supportLevel: 1,
    primaryLanguages: ["Rust", "JavaScript"],
    toolchains: [
      {
        id: "cargo-near",
        name: "cargo-near",
        pinnedVersion: "0.13.x",
        language: "Rust",
        cliCommand: "cargo near --version",
        verifiedAt: "2026-11-26",
      },
    ],
    capabilities: {
      editorSyntax: true,
      browserCompile: false,
      browserExecute: false,
      localCliCompile: false,
      localCliTest: false,
      remoteHiddenEval: false,
      competitionIsolated: false,
    },
    architectureNotes:
      "Sharded WebAssembly async-call model. Distinct adapter from Cosmos CosmWasm.",
    officialDocsUrl: "https://docs.near.org/",
  },
  {
    id: "cosmos",
    name: "Cosmos",
    shortName: "ATOM",
    adapterId: "cosmos-cosmwasm-adapter",
    supportLevel: 1,
    primaryLanguages: ["Rust"],
    toolchains: [
      {
        id: "cosmwasm",
        name: "CosmWasm / cw-multi-test",
        pinnedVersion: "2.1.x",
        language: "Rust",
        cliCommand: "cargo --version",
        verifiedAt: "2026-11-26",
      },
    ],
    capabilities: {
      editorSyntax: true,
      browserCompile: false,
      browserExecute: false,
      localCliCompile: false,
      localCliTest: false,
      remoteHiddenEval: false,
      competitionIsolated: false,
    },
    architectureNotes:
      "Actor-model CosmWasm contracts over IBC. Distinct adapter from NEAR.",
    officialDocsUrl: "https://docs.cosmwasm.com/",
  },
  {
    id: "algorand",
    name: "Algorand",
    shortName: "ALGO",
    adapterId: "algorand-algokit-adapter",
    supportLevel: 0,
    primaryLanguages: ["TEAL", "PyTeal", "Python"],
    toolchains: [
      {
        id: "algokit",
        name: "AlgoKit CLI",
        pinnedVersion: "2.4.x",
        language: "Python",
        cliCommand: "algokit --version",
        verifiedAt: "2026-11-26",
      },
    ],
    capabilities: {
      editorSyntax: false,
      browserCompile: false,
      browserExecute: false,
      localCliCompile: false,
      localCliTest: false,
      remoteHiddenEval: false,
      competitionIsolated: false,
    },
    architectureNotes: "AVM stateful & stateless smart contracts. Planned for Phase 4.",
    officialDocsUrl: "https://developer.algorand.org/",
  },
  {
    id: "tezos",
    name: "Tezos",
    shortName: "XTZ",
    adapterId: "tezos-ligo-adapter",
    supportLevel: 0,
    primaryLanguages: ["Michelson", "SmartPy", "LIGO"],
    toolchains: [
      {
        id: "ligo",
        name: "LIGO Compiler",
        pinnedVersion: "1.9.x",
        language: "LIGO",
        cliCommand: "ligo --version",
        verifiedAt: "2026-11-26",
      },
    ],
    capabilities: {
      editorSyntax: false,
      browserCompile: false,
      browserExecute: false,
      localCliCompile: false,
      localCliTest: false,
      remoteHiddenEval: false,
      competitionIsolated: false,
    },
    architectureNotes: "Formal-verification-oriented Michelson stack VM. Planned for Phase 4.",
    officialDocsUrl: "https://tezos.com/developers/",
  },
] as const;

export function getEcosystemById(id: string): EcosystemRecord | undefined {
  return ECOSYSTEM_REGISTRY.find((eco) => eco.id === id);
}

export function getSupportedExecutionEcosystems(): EcosystemRecord[] {
  return ECOSYSTEM_REGISTRY.filter((eco) => eco.supportLevel >= 3);
}
