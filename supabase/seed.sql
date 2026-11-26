-- CONSINZO Seed Data (Roles, Categories, Initial Ecosystems, Achievements)

INSERT INTO public.roles (name, description) VALUES
  ('developer', 'Standard authenticated engineering user'),
  ('content_editor', 'Can author and edit draft knowledge entries'),
  ('competition_organizer', 'Can create and manage competitions'),
  ('security_reviewer', 'Can review audit reports and security mission findings'),
  ('ecosystem_manager', 'Can manage ecosystem registry and toolchain metadata'),
  ('challenge_manager', 'Can review, validate, and publish challenges'),
  ('platform_admin', 'Platform operations and moderation administrator'),
  ('super_admin', 'Full administrative control')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.challenge_categories (id, label, description) VALUES
  ('programming-fundamentals', 'Programming Fundamentals', 'Core syntax, types, memory, and deterministic execution'),
  ('smart-contract-engineering', 'Smart Contract Engineering', 'Stateful contracts, modifiers, events, and patterns'),
  ('protocol-implementation', 'Protocol Implementation', 'AMMs, vaults, governance, and core protocol mechanics'),
  ('defi-engineering', 'DeFi Engineering', 'Lending, pricing curves, collateralization, and accounting'),
  ('token-standards', 'Token Standards', 'ERC-20, ERC-721, ERC-1155, ERC-4626 and cross-ecosystem standards'),
  ('blockchain-infrastructure', 'Blockchain Infrastructure', 'Indexing, signatures, Merkle proofs, and verification'),
  ('advanced-blockchain-systems', 'Advanced Blockchain Systems', 'Account abstraction, intents, and gas optimization'),
  ('security-engineering', 'Security Engineering', 'Exploit reproduction, patching, and invariant defense'),
  ('cross-chain-development', 'Cross-Chain Development', 'Messaging verification, replay protection, and bridges'),
  ('ecosystem-integrations', 'Ecosystem Integrations', 'SDKs, RPCs, and native toolchain integrations')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.ecosystems (id, name, short_name, adapter_id, support_level, architecture_notes, official_docs_url) VALUES
  ('ethereum-evm', 'Ethereum / EVM', 'EVM', 'evm-foundry-solc', 4, 'Primary Phase 1 ecosystem with real solc compilation and EVM test execution.', 'https://docs.soliditylang.org/'),
  ('solana', 'Solana', 'SOL', 'solana-anchor-adapter', 1, 'Account-based Sealevel runtime. Editor syntax support only in Phase 1.', 'https://solana.com/docs'),
  ('sui', 'Sui', 'SUI', 'sui-move-adapter', 0, 'Object-centric Move model (distinct from Aptos). Reference only in Phase 1.', 'https://docs.sui.io/'),
  ('aptos', 'Aptos', 'APT', 'aptos-move-adapter', 0, 'Account-resource Move model (distinct from Sui). Reference only in Phase 1.', 'https://aptos.dev/'),
  ('starknet', 'Starknet', 'STRK', 'starknet-cairo-adapter', 0, 'Validity-rollup Cairo VM ecosystem. Reference only in Phase 1.', 'https://docs.starknet.io/'),
  ('cardano', 'Cardano', 'ADA', 'cardano-aiken-adapter', 0, 'Extended UTXO validator model. Reference only in Phase 1.', 'https://aiken-lang.org/'),
  ('near', 'NEAR', 'NEAR', 'near-wasm-adapter', 1, 'Sharded WebAssembly async-call model (distinct from Cosmos). Editor syntax only.', 'https://docs.near.org/'),
  ('cosmos', 'Cosmos', 'ATOM', 'cosmos-cosmwasm-adapter', 1, 'Actor-model CosmWasm over IBC (distinct from NEAR). Editor syntax only.', 'https://docs.cosmwasm.com/'),
  ('algorand', 'Algorand', 'ALGO', 'algorand-algokit-adapter', 0, 'AVM stateful & stateless smart contracts. Reference only in Phase 1.', 'https://developer.algorand.org/'),
  ('tezos', 'Tezos', 'XTZ', 'tezos-ligo-adapter', 0, 'Michelson stack VM. Reference only in Phase 1.', 'https://tezos.com/developers/')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.achievements (id, title, description, criteria_type) VALUES
  ('first-verified-pass', 'First Verified Pass', 'Passed all public and hidden evaluation tests on an engineering challenge.', 'server_verified_submission'),
  ('evm-token-architect', 'Token Standard Architect', 'Completed ERC-20 and ERC-721 engineering challenges with verified tests.', 'server_verified_category'),
  ('security-defender', 'Invariant Defender', 'Identified and patched a critical smart contract vulnerability.', 'server_verified_security'),
  ('defi-protocol-builder', 'DeFi Protocol Architect', 'Completed Constant Product AMM and ERC-4626 Yield Vault challenges.', 'server_verified_defi'),
  ('security-arena-specialist', 'Security Arena Specialist', 'Completed 5 or more validated Security Arena missions.', 'server_verified_security_count'),
  ('contest-competitor', 'Contest Competitor', 'Registered and scored in a timed CONSINZO engineering competition.', 'server_verified_contest')
ON CONFLICT (id) DO NOTHING;
