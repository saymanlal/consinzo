import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { validateChallengeDirectory, validateProjectSnapshot } from "./index";

describe("@consinzo/validators", () => {
  it("rejects path traversal and protected path overwrites in snapshots", () => {
    expect(() =>
      validateProjectSnapshot([{ path: "../etc/passwd", content: "x" }])
    ).toThrow(/Unsafe or invalid/);

    expect(() =>
      validateProjectSnapshot([{ path: "evaluation/hidden/Test.t.sol", content: "x" }])
    ).toThrow(/protected path/);
  });

  it("rejects malformed challenge packages missing manifest or starter files", () => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "consinzo-bad-chal-"));
    fs.writeFileSync(path.join(tmpDir, "challenge.yaml"), "id: bad\ntitle: X\n");
    const res = validateChallengeDirectory(tmpDir);
    expect(res.valid).toBe(false);
    expect(res.errors.length).toBeGreaterThan(0);
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });
});
