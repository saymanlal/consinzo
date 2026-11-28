export interface KnowledgeSection {
  heading: string;
  content: string;
  codeExample?: string;
}

export interface KnowledgeEntry {
  slug: string;
  ecosystemId: string;
  entryType: "language" | "compiler" | "sdk" | "framework" | "standard" | "protocol" | "tool";
  title: string;
  summary: string;
  source: string;
  sourceUrl: string;
  applicableVersion: string;
  lastVerifiedAt: string;
  reviewStatus: "verified" | "draft" | "needs_update";
  bodySections: readonly KnowledgeSection[];
  relatedChallengeSlugs: readonly string[];
}

export interface ProtocolLabSpec {
  slug: string;
  title: string;
  category: string;
  summary: string;
  architectureSteps: readonly string[];
  invariants: readonly string[];
  linkedChallengeSlug?: string;
}

export interface LearningPathSpec {
  slug: string;
  title: string;
  ecosystemId: string;
  difficulty: string;
  description: string;
  challengeSlugs: readonly string[];
}

export const KNOWLEDGE_ENTRIES: readonly KnowledgeEntry[] = [
  {
    slug: "solidity-0-8-arithmetic",
    ecosystemId: "ethereum-evm",
    entryType: "language",
    title: "Solidity 0.8.x Checked Arithmetic & Unchecked Blocks",
    summary:
      "Solidity ^0.8.0 enforces automatic overflow/underflow panics (Panic(0x11)) on integer math by default, making unchecked{} strictly an intentional gas optimization after explicit bounds proofs.",
    source: "Solidity Language Documentation",
    sourceUrl: "https://docs.soliditylang.org/en/v0.8.28/",
    applicableVersion: "solc 0.8.28",
    lastVerifiedAt: "2026-11-27",
    reviewStatus: "verified",
    bodySections: [
      {
        heading: "Default Checked Arithmetic vs Unchecked Gas Optimization",
        content:
          "Starting in Solidity 0.8.0, all unsigned and signed arithmetic reverts via Panic(0x11) on overflow or underflow. Only place increments or subtractions inside unchecked { ... } after establishing an invariant such as if (balance < amount) revert InsufficientBalance();.",
        codeExample: `if (balances[msg.sender] < amount) revert InsufficientBalance();\nunchecked {\n    balances[msg.sender] -= amount;\n}`,
      },
      {
        heading: "Precision Loss & Multiplication Before Division",
        content:
          "Integer division in the EVM truncates toward zero. Always perform multiplications before divisions (for example (amount * feeBps) / 10_000) and guard zero denominators to avoid silent zero-fee or zero-share rounding bugs.",
      },
    ],
    relatedChallengeSlugs: ["erc20-token-vault", "precision-loss-staking", "unsafe-downcast-guard"],
  },
  {
    slug: "eip-4626-tokenized-vaults",
    ecosystemId: "ethereum-evm",
    entryType: "standard",
    title: "EIP-4626 Tokenized Vaults & Inflation Attack Mitigation",
    summary:
      "ERC-4626 standardizes yield-bearing share vaults. Naive share math (assets * totalSupply / totalAssets) is vulnerable to first-depositor donation inflation unless virtual offset shares or internal asset accounting are used.",
    source: "Ethereum EIPs — EIP-4626",
    sourceUrl: "https://eips.ethereum.org/EIPS/eip-4626",
    applicableVersion: "Final",
    lastVerifiedAt: "2026-11-27",
    reviewStatus: "verified",
    bodySections: [
      {
        heading: "First-Depositor Share Inflation Mechanics",
        content:
          "An attacker deposits 1 wei for 1 share, transfers 10,000 underlying tokens directly into the vault, and causes subsequent depositors under 10,001 tokens to round down to 0 minted shares.",
      },
      {
        heading: "Virtual Shares Offset & Rounding Direction",
        content:
          "Per EIP-4626, deposit() and redeem() should round down (favoring the vault), while mint() and withdraw() round up. Adding a virtual offset to totalSupply and totalAssets prevents single-wei exchange-rate manipulation.",
        codeExample: `uint256 shares = assets.mulDiv(totalSupply() + 10 ** decimalsOffset, totalAssets() + 1, Math.Rounding.Floor);`,
      },
    ],
    relatedChallengeSlugs: ["erc4626-tokenized-vault", "constant-product-amm"],
  },
  {
    slug: "foundry-cheatcodes-vm",
    ecosystemId: "ethereum-evm",
    entryType: "framework",
    title: "Foundry-Style Testing & Deterministic EVM Cheatcodes",
    summary:
      "Contract-based Solidity testing using vm.prank, vm.deal, vm.warp, and vm.expectRevert enables reproducible adversarial exploit reproduction and invariant validation.",
    source: "Foundry Book",
    sourceUrl: "https://book.getfoundry.sh/",
    applicableVersion: "forge-std compatible",
    lastVerifiedAt: "2026-11-27",
    reviewStatus: "verified",
    bodySections: [
      {
        heading: "Caller, ETH Balance, and Timestamp Manipulation",
        content:
          "Use vm.prank(attacker) to impersonate external EOAs on the next external call, vm.deal(user, amount) to seed ETH balances cleanly, and vm.warp(nextTimestamp) to advance block.timestamp across timelocks and vesting cliffs.",
      },
      {
        heading: "Verifying Expected Reverts",
        content:
          "Assert security boundaries positively by prefixing unauthorized or invalid calls with vm.expectRevert(...) rather than assuming happy-path tests cover access control.",
        codeExample: `vm.prank(attacker);\nvm.expectRevert();\nvault.withdraw(1 ether);`,
      },
    ],
    relatedChallengeSlugs: ["reentrancy-vault-defense", "timelock-governance"],
  },
  {
    slug: "near-js-sdk-account-model",
    ecosystemId: "near",
    entryType: "sdk",
    title: "NEAR Account Model, Predecessor Attribution & LookupMap Storage",
    summary:
      "NEAR uses human-readable named accounts, sharded async execution, and trie-backed collections (LookupMap). Access control must authenticate near.predecessorAccountId() rather than signerAccountId().",
    source: "NEAR Protocol Documentation",
    sourceUrl: "https://docs.near.org/build/smart-contracts/anatomy/anatomy",
    applicableVersion: "near-sdk-js 2.x",
    lastVerifiedAt: "2026-11-27",
    reviewStatus: "verified",
    bodySections: [
      {
        heading: "Predecessor vs Signer Account ID",
        content:
          "signerAccountId() identifies the EOA that signed the originating transaction, whereas predecessorAccountId() identifies the immediate contract or account invoking the current method. Checking signer allows malicious intermediary contracts to spoof authorization (identical to Ethereum tx.origin).",
        codeExample: `const caller = near.predecessorAccountId();\nassert(caller === this.owner, "Unauthorized: owner only");`,
      },
      {
        heading: "Deterministic Trie Collections & YoctoNEAR",
        content:
          "Balances and deposits use bigint in yoctoNEAR (10^24 per NEAR). Store dynamic key/value records in LookupMap with explicit prefix strings so storage keys never collide across state fields.",
      },
    ],
    relatedChallengeSlugs: [
      "near-counter-contract",
      "near-ft-escrow",
      "near-dao-voting",
      "near-signer-predecessor-bypass",
      "near-callback-rollback-guard",
    ],
  },
  {
    slug: "solana-pda-signer-verification",
    ecosystemId: "solana",
    entryType: "protocol",
    title: "Solana Account Validation, PDAs & Anchor Security Constraints",
    summary:
      "Solana separates stateless program bytecode from externally passed accounts. Every instruction must explicitly verify account ownership, signer flags, and canonical PDA bump seeds.",
    source: "Solana & Anchor Documentation",
    sourceUrl: "https://www.anchor-lang.com/docs",
    applicableVersion: "Anchor 0.30.x",
    lastVerifiedAt: "2026-11-27",
    reviewStatus: "verified",
    bodySections: [
      {
        heading: "Canonical PDA Derivation & Owner Checks",
        content:
          "Because callers pass arbitrary AccountInfo references into instructions, failing to constrain account.owner == program_id or omitting PDA seed checks lets attackers substitute spoofed state accounts.",
        codeExample: `#[account(\n  mut,\n  seeds = [b"escrow", authority.key().as_ref()],\n  bump\n)]\npub escrow: Account<'info, EscrowState>,`,
      },
    ],
    relatedChallengeSlugs: [],
  },
  {
    slug: "cosmos-cosmwasm-actor-model",
    ecosystemId: "cosmos",
    entryType: "framework",
    title: "CosmWasm Actor Model & Reply/SubMsg Isolation",
    summary:
      "CosmWasm contracts execute in a WebAssembly VM using explicit InstantiateMsg, ExecuteMsg, and QueryMsg JSON schemas and actor-style asynchronous SubMsg replies instead of shared reentrant callbacks.",
    source: "CosmWasm Book",
    sourceUrl: "https://book.cosmwasm.com/",
    applicableVersion: "cosmwasm-std 2.1",
    lastVerifiedAt: "2026-11-27",
    reviewStatus: "verified",
    bodySections: [
      {
        heading: "Checks-Effects-Responses in CosmWasm",
        content:
          "CosmWasm commits contract storage updates from DepsMut before dispatching returned BankMsg or WasmMsg responses, structurally reducing synchronous reentrancy while still requiring careful handling of SubMsg reply state.",
      },
    ],
    relatedChallengeSlugs: [],
  },
  {
    slug: "sui-object-ownership-move",
    ecosystemId: "sui",
    entryType: "language",
    title: "Sui Move Object Ownership & Linear Resource Abilities",
    summary:
      "Sui Move represents on-chain state as typed objects with key, store, copy, and drop abilities, enabling parallel transaction execution for owned objects and explicit consensus only for shared objects.",
    source: "Sui Move Documentation",
    sourceUrl: "https://docs.sui.io/concepts/sui-move-concepts",
    applicableVersion: "Sui Move 2024",
    lastVerifiedAt: "2026-11-27",
    reviewStatus: "verified",
    bodySections: [
      {
        heading: "Linear Asset Guarantees",
        content:
          "Assets lacking copy and drop abilities cannot be implicitly duplicated or silently discarded at compile time, eliminating whole classes of accounting double-spend bugs.",
      },
    ],
    relatedChallengeSlugs: [],
  },
  {
    slug: "aptos-account-resources-move",
    ecosystemId: "aptos",
    entryType: "language",
    title: "Aptos Account-Resource Storage & Signer Capabilities",
    summary:
      "Aptos stores Move resources directly under account addresses via move_to and borrow_global_mut, separating global table storage from caller &signer authorization.",
    source: "Aptos Developer Documentation",
    sourceUrl: "https://aptos.dev/en/build/smart-contracts",
    applicableVersion: "Aptos CLI 4.x",
    lastVerifiedAt: "2026-11-27",
    reviewStatus: "verified",
    bodySections: [
      {
        heading: "Resource Groups & Signer Refs",
        content:
          "Privileged account actions take &signer (non-forgeable by unauthenticated callers) and verify explicit acquires annotations at compile time.",
      },
    ],
    relatedChallengeSlugs: [],
  },
  {
    slug: "starknet-cairo-felt-storage",
    ecosystemId: "starknet",
    entryType: "compiler",
    title: "Starknet Cairo ZK-Provable Execution & felt252 Arithmetic",
    summary:
      "Cairo compiles smart contracts to Sierra intermediate representation and STARK-provable CASM traces, using finite-field felt252 primes alongside overflow-checked u128/u256 types.",
    source: "Cairo Book",
    sourceUrl: "https://book.cairo-lang.org/",
    applicableVersion: "Scarb 2.8 / Cairo 2",
    lastVerifiedAt: "2026-11-27",
    reviewStatus: "verified",
    bodySections: [
      {
        heading: "Sierra Safety Layer & Storage Components",
        content:
          "Unlike raw felt252 modular field wraparound, explicit u128/u256 types verify range bounds inside ZK constraints, while Sierra guarantees every valid Cairo program produces provable non-failing traces.",
      },
    ],
    relatedChallengeSlugs: [],
  },
  {
    slug: "cardano-eutxo-aiken-validators",
    ecosystemId: "cardano",
    entryType: "language",
    title: "Cardano eUTXO Datum/Redeemer Validation with Aiken",
    summary:
      "Cardano validators are pure predicates (Datum, Redeemer, ScriptContext) -> Bool verifying whether a transaction spending an unspent UTXO satisfies conservation and authorization rules.",
    source: "Aiken Language Documentation",
    sourceUrl: "https://aiken-lang.org/language-tour/hello-world",
    applicableVersion: "Aiken v1.1",
    lastVerifiedAt: "2026-11-27",
    reviewStatus: "verified",
    bodySections: [
      {
        heading: "Preventing Double Satisfaction in eUTXO",
        content:
          "When multiple script UTXOs are spent in the same transaction, each validator must bind its expected output datum/value specifically to its own continuing OutputReference to prevent double-satisfaction exploits.",
      },
    ],
    relatedChallengeSlugs: [],
  },
  {
    slug: "algorand-avm-pyteal-inner-txns",
    ecosystemId: "algorand",
    entryType: "tool",
    title: "Algorand Virtual Machine (AVM) & Atomic Group Transactions",
    summary:
      "Algorand combines stateful TEAL applications compiled from Python (Puya/Algorand Python) with native Layer-1 atomic transaction groups and ASA asset opt-in invariants.",
    source: "Algorand Developer Portal",
    sourceUrl: "https://developer.algorand.org/docs/get-details/dapps/smart-contracts/",
    applicableVersion: "AlgoKit 2.4",
    lastVerifiedAt: "2026-11-27",
    reviewStatus: "verified",
    bodySections: [
      {
        heading: "Group Transaction Size & Rekey Safety",
        content:
          "Always verify Global.group_size and every transaction's RekeyTo == Global.zero_address and CloseRemainderTo == Global.zero_address unless explicitly closing out.",
      },
    ],
    relatedChallengeSlugs: [],
  },
  {
    slug: "tezos-michelson-ligo-callbacks",
    ecosystemId: "tezos",
    entryType: "compiler",
    title: "Tezos Michelson Stack VM & LIGO Safe Operation Ordering",
    summary:
      "Tezos smart contracts execute in Michelson and emit delayed internal operations evaluated in FIFO/breadth-first order rather than arbitrary mid-function external calls.",
    source: "Tezos & LIGO Documentation",
    sourceUrl: "https://ligolang.org/docs/intro/introduction",
    applicableVersion: "LIGO 1.x",
    lastVerifiedAt: "2026-11-27",
    reviewStatus: "verified",
    bodySections: [
      {
        heading: "Operations List & Ticket Linearity",
        content:
          "Every entrypoint returns a pair (operation list * storage). Because storage mutations are returned alongside emitted operations rather than interleaved around external calls, ticket linearity and storage ordering prevent classic callbacks.",
      },
    ],
    relatedChallengeSlugs: [],
  },
];

export function getKnowledgeEntryBySlug(slug: string): KnowledgeEntry | undefined {
  return KNOWLEDGE_ENTRIES.find((entry) => entry.slug === slug);
}

export const PROTOCOL_LABS: readonly ProtocolLabSpec[] = [
  {
    slug: "constant-product-amm",
    title: "Constant-Product AMM (x·y = k)",
    category: "DEX & Liquidity Math",
    summary:
      "Explore invariant pricing, swap fees, liquidity mint/burn proportionality, and slippage enforcement with deterministic fixed-point integer rounding.",
    architectureSteps: [
      "Sync reserves strictly from internal tracked state rather than spot token balance alone.",
      "Apply swap fee before enforcing x' · y' >= x · y invariant.",
      "Require caller-provided minimum output (minAmountOut) to neutralize sandwich attacks.",
    ],
    invariants: [
      "Reserve product k never decreases across swaps",
      "First LP mint locks MINIMUM_LIQUIDITY or seeds proportional sqrt(x·y)",
      "Fee-on-transfer discrepancies detected via actual balance delta",
    ],
    linkedChallengeSlug: "constant-product-amm",
  },
  {
    slug: "erc4626-tokenized-vault",
    title: "ERC-4626 Tokenized Vault",
    category: "Yield & Vault Accounting",
    summary:
      "Standardized share-to-asset vault accounting with deterministic rounding directions and defense against first-depositor inflation donations.",
    architectureSteps: [
      "Compute previewDeposit rounding down and previewWithdraw rounding up.",
      "Track or offset virtual shares/assets so 1-wei donations cannot zero out victim shares.",
      "Update shares and emit Deposit/Withdraw events cleanly before external token transfers.",
    ],
    invariants: [
      "No user can extract more underlying assets than proportional share ownership",
      "Zero-share deposits above minimum dust revert or stay strictly protected",
    ],
    linkedChallengeSlug: "erc4626-tokenized-vault",
  },
  {
    slug: "dutch-auction-engine",
    title: "Dutch Auction Price Decay Engine",
    category: "Auction & Clearing",
    summary:
      "Linear time-decay clearing auction that computes exact block-timestamp unit prices, collects payment, and refunds excess ETH safely.",
    architectureSteps: [
      "Clamp elapsed time cleanly to [0, duration] after auction start.",
      "Compute price = startPrice - ((startPrice - reservePrice) * elapsed) / duration.",
      "Verify msg.value >= cost and refund msg.value - cost immediately.",
    ],
    invariants: [
      "Clearing price monotonically decreases until hitting reserve floor",
      "Contract never retains unrefunded bidder overpayment",
    ],
    linkedChallengeSlug: "dutch-auction-engine",
  },
  {
    slug: "flash-lender-eip3156",
    title: "EIP-3156 Flash Loan Engine",
    category: "Liquidity & Callbacks",
    summary:
      "Atomic uncollateralized borrowing requiring borrower callback execution and strict principal + fee repayment check within the same transaction.",
    architectureSteps: [
      "Snapshot balanceBefore and compute fee = flashFee(token, amount).",
      "Transfer tokens and call IERC3156FlashBorrower.onFlashLoan verifying magic return constant.",
      "Assert balanceAfter >= balanceBefore + fee and restrict arbitrary nested reentrancy.",
    ],
    invariants: [
      "Pool principal + fee never decreases by transaction end",
      "Magic keccak256('ERC3156FlashBorrower.onFlashLoan') strictly validated",
    ],
    linkedChallengeSlug: "flash-lender-eip3156",
  },
];

export const LEARNING_PATHS: readonly LearningPathSpec[] = [
  {
    slug: "evm-solidity-core",
    title: "EVM & Solidity Core Engineering",
    ecosystemId: "ethereum-evm",
    difficulty: "Beginner → Intermediate",
    description:
      "Master ERC-20, ERC-721, Merkle verification, and multi-signature treasury patterns with real Solidity compilation and EVM execution.",
    challengeSlugs: [
      "erc20-token-vault",
      "erc721-royalty-nft",
      "merkle-airdrop-claim",
      "access-control-multisig",
    ],
  },
  {
    slug: "defi-protocol-engineering",
    title: "DeFi & Protocol Invariant Engineering",
    ecosystemId: "ethereum-evm",
    difficulty: "Intermediate → Hard",
    description:
      "Build production-grade constant-product AMMs, ERC-4626 vaults, flash lenders, and linear Dutch auctions from scratch.",
    challengeSlugs: [
      "linear-vesting-cliff",
      "dutch-auction-engine",
      "constant-product-amm",
      "erc4626-tokenized-vault",
      "flash-lender-eip3156",
    ],
  },
  {
    slug: "security-defense-arena",
    title: "Smart Contract Security & Exploit Defense",
    ecosystemId: "ethereum-evm",
    difficulty: "Intermediate → Hard",
    description:
      "Diagnose and patch real-world vulnerabilities including reentrancy, signature replay, flash-loan governance manipulation, and read-only oracle exploits.",
    challengeSlugs: [
      "tx-origin-auth-bypass",
      "reentrancy-vault-defense",
      "signature-replay-escrow",
      "flash-loan-governance-guard",
      "read-only-reentrancy-oracle",
    ],
  },
  {
    slug: "near-typescript-builder",
    title: "NEAR Smart Contract & Security Engineering (TypeScript)",
    ecosystemId: "near",
    difficulty: "Beginner → Hard",
    description:
      "Write and verify NEAR TypeScript contracts using predecessor attribution, LookupMap storage, DAO quorum mechanics, and async callback defense.",
    challengeSlugs: [
      "near-counter-contract",
      "near-ft-escrow",
      "near-dao-voting",
      "near-signer-predecessor-bypass",
      "near-callback-rollback-guard",
    ],
  },
];
