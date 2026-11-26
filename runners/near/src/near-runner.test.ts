import { describe, expect, it } from "vitest";
import { NearRunner } from "./index";

describe("@consinzo/runner-near", () => {
  const runner = new NearRunner();

  it("compiles and executes NEAR TypeScript contracts in an isolated VM context", async () => {
    const report = await runner.runTests([
      {
        path: "src/Counter.ts",
        content: `import { near } from "near-sdk-js";
export class Counter {
  public count = 0;
  public lastCaller = "";
  inc(): void {
    this.count += 1;
    this.lastCaller = near.predecessorAccountId();
  }
}`,
      },
      {
        path: "test/Counter.t.ts",
        content: `import { near, assertEq } from "near-sdk-js";
import { Counter } from "../src/Counter";
export function testIncrementTracksCaller(): void {
  const c = new Counter();
  near._setContext({ predecessorAccountId: "bob.testnet" });
  c.inc();
  assertEq(c.count, 1);
  assertEq(c.lastCaller, "bob.testnet");
}`,
      },
    ]);

    expect(report.compiled).toBe(true);
    expect(report.status).toBe("passed");
    expect(report.publicTests).toHaveLength(1);
    expect(report.publicTests[0]?.passed).toBe(true);
  });

  it("reports TypeScript compiler diagnostics on type errors", async () => {
    const report = await runner.runTests([
      {
        path: "src/Broken.ts",
        content: `export function bad(x: number): number { return "nope"; }`,
      },
    ]);

    expect(report.compiled).toBe(false);
    expect(report.status).toBe("compilation_error");
    expect(report.diagnostics[0]?.severity).toBe("error");
  });
});
