import type { EcosystemRunner } from "@consinzo/execution-sdk";
import { EvmRunner } from "@consinzo/runner-evm";
import { NearRunner } from "@consinzo/runner-near";
import { ConsinzoError } from "@consinzo/shared";

/**
 * Resolves the concrete server-side EcosystemRunner implementation for a given
 * challenge ecosystem. Ecosystems without a real verified compiler/runner
 * throw an explicit 422 error instead of faking execution.
 */
export function getEcosystemRunner(ecosystem: string): EcosystemRunner {
  switch (ecosystem) {
    case "ethereum-evm":
      return new EvmRunner();
    case "near":
      return new NearRunner();
    default:
      throw new ConsinzoError(
        "ECOSYSTEM_RUNNER_UNAVAILABLE",
        `Server-side compiler/test runner is not yet available for ecosystem "${ecosystem}". Currently active runners: ethereum-evm (solc + EthereumJS EVM) and near (NEAR TypeScript VM).`,
        422
      );
  }
}
