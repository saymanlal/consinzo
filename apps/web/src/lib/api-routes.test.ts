import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { GET as getHealth } from "../app/api/v1/health/route";
import { GET as getEcosystems } from "../app/api/v1/ecosystems/route";
import { GET as listChallengesApi } from "../app/api/v1/challenges/route";
import { POST as compileExecution } from "../app/api/v1/execution/compile/route";
import { getEcosystemRunner } from "./runner-dispatch";

describe("Multi-Ecosystem API Route & Dispatch Integration", () => {
  it("reports EVM and NEAR runners active on /api/v1/health and /api/v1/ecosystems", async () => {
    const healthRes = await getHealth();
    expect(healthRes.status).toBe(200);
    const health = (await healthRes.json()) as {
      status: string;
      execution: {
        localEvmRunner: boolean;
        localNearRunner: boolean;
        activeEcosystems: string[];
      };
    };
    expect(health.status).toBe("ok");
    expect(health.execution.localEvmRunner).toBe(true);
    expect(health.execution.localNearRunner).toBe(true);
    expect(health.execution.activeEcosystems).toEqual(["ethereum-evm", "near"]);

    const ecoRes = await getEcosystems();
    expect(ecoRes.status).toBe(200);
    const ecoJson = (await ecoRes.json()) as {
      ecosystems: Array<{ id: string; supportLevel: number }>;
    };
    expect(ecoJson.ecosystems.find((e) => e.id === "ethereum-evm")?.supportLevel).toBe(4);
    expect(ecoJson.ecosystems.find((e) => e.id === "near")?.supportLevel).toBe(3);
  });

  it("compiles and runs authoritative public tests via /api/v1/execution/compile for NEAR and EVM without hidden leakage", async () => {
    const nearCounterRef = fs.readFileSync(
      path.resolve(
        process.cwd(),
        "../../content/challenges/near-counter-contract/solution/reference/Counter.ts"
      ),
      "utf8"
    );

    const nearRes = await compileExecution(
      new Request("http://localhost/api/v1/execution/compile", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          challengeSlug: "near-counter-contract",
          files: [
            { path: "src/Counter.ts", content: nearCounterRef },
            { path: "test/Counter.t.ts", content: "// tampered client test must be ignored" },
          ],
        }),
      })
    );
    expect(nearRes.status).toBe(200);
    const nearReport = (await nearRes.json()) as {
      runnerName: string;
      status: string;
      compiled: boolean;
      publicTests: Array<{ passed: boolean }>;
      hiddenTestsSummary: { evaluated: boolean; total: number };
    };
    expect(nearReport.runnerName).toBe("near-ts-vm");
    expect(nearReport.compiled).toBe(true);
    expect(nearReport.status).toBe("passed");
    expect(nearReport.publicTests.length).toBe(3);
    expect(nearReport.hiddenTestsSummary.evaluated).toBe(false);
    expect(nearReport.hiddenTestsSummary.total).toBe(0);

    const evmTokenRef = fs.readFileSync(
      path.resolve(
        process.cwd(),
        "../../content/challenges/erc20-token-vault/solution/reference/ConsinzoToken.sol"
      ),
      "utf8"
    );

    const evmRes = await compileExecution(
      new Request("http://localhost/api/v1/execution/compile", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          challengeSlug: "erc20-token-vault",
          files: [{ path: "src/ConsinzoToken.sol", content: evmTokenRef }],
        }),
      })
    );
    expect(evmRes.status).toBe(200);
    const evmReport = (await evmRes.json()) as {
      runnerName: string;
      status: string;
      compiled: boolean;
      hiddenTestsSummary: { evaluated: boolean };
    };
    expect(evmReport.runnerName).toBe("solc-ethereumjs-evm");
    expect(evmReport.compiled).toBe(true);
    expect(evmReport.status).toBe("passed");
    expect(evmReport.hiddenTestsSummary.evaluated).toBe(false);
  });

  it("explicitly rejects ecosystems without a provisioned server runner with HTTP 422", () => {
    expect(() => getEcosystemRunner("solana")).toThrowError(/not yet available/i);
  });

  it("supports slug search and NEAR security mission filtering via GET /api/v1/challenges", async () => {
    const slugRes = await listChallengesApi(
      new Request("http://localhost/api/v1/challenges?q=near-callback-rollback-guard")
    );
    expect(slugRes.status).toBe(200);
    const slugJson = (await slugRes.json()) as {
      total: number;
      challenges: Array<{ slug: string }>;
    };
    expect(slugJson.total).toBe(1);
    expect(slugJson.challenges[0]?.slug).toBe("near-callback-rollback-guard");

    const nearSecRes = await listChallengesApi(
      new Request("http://localhost/api/v1/challenges?ecosystem=near&security=true")
    );
    expect(nearSecRes.status).toBe(200);
    const nearSecJson = (await nearSecRes.json()) as {
      total: number;
      challenges: Array<{ slug: string }>;
    };
    expect(nearSecJson.total).toBe(2);
  });
});
