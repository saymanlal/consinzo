import { describe, expect, it } from "vitest";
import { calculateScore } from "./index";

describe("@consinzo/scoring", () => {
  it("awards full score when all public and hidden tests pass within gas budget with zero warnings", () => {
    const res = calculateScore({
      maxPoints: 100,
      weights: {
        functional_correctness: 60,
        security_invariants: 25,
        efficiency: 10,
        code_quality: 5,
      },
      compiled: true,
      compilerWarningsCount: 0,
      gasBudget: 120000,
      averageGasUsed: 95000,
      publicResults: [
        { name: "testMint", passed: true, suite: "public", gasUsed: 95000 },
        { name: "testTransfer", passed: true, suite: "public", gasUsed: 95000 },
      ],
      hiddenResults: [
        { name: "secret_invariant_1", passed: true, suite: "hidden", gasUsed: 90000 },
      ],
    });

    expect(res.passed).toBe(true);
    expect(res.totalScore).toBe(100);
    expect(res.hiddenSummary).toEqual({
      evaluated: true,
      total: 1,
      passed: 1,
      failed: 0,
    });
  });

  it("never leaks hidden test names and fails overall if hidden tests fail", () => {
    const res = calculateScore({
      maxPoints: 100,
      weights: {
        functional_correctness: 60,
        security_invariants: 25,
        efficiency: 10,
        code_quality: 5,
      },
      compiled: true,
      compilerWarningsCount: 0,
      publicResults: [{ name: "testBasic", passed: true, suite: "public" }],
      hiddenResults: [
        { name: "secret_overflow_edge_case", passed: false, suite: "hidden", errorMessage: "expected revert" },
      ],
    });

    expect(res.passed).toBe(false);
    expect(res.totalScore).toBeLessThan(100);
    const serialized = JSON.stringify(res);
    expect(serialized).not.toContain("secret_overflow_edge_case");
    expect(serialized).not.toContain("expected revert");
  });
});
