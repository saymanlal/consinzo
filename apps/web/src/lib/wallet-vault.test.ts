import { describe, expect, it } from "vitest";
import { english, generateMnemonic, mnemonicToAccount } from "viem/accounts";
import { decryptVault, encryptVault, isVaultFile } from "./wallet-vault";

describe("Wallet vault (browser-side encryption of the recovery phrase)", () => {
  const mnemonic = generateMnemonic(english);
  const address = mnemonicToAccount(mnemonic).address;

  it("round-trips the phrase with the right password and never stores it in clear", async () => {
    const vault = await encryptVault(address, mnemonic, "correct horse battery");
    const serialized = JSON.stringify(vault);
    for (const word of mnemonic.split(" ")) {
      // No 12-word phrase substring survives; individual short words could collide with base64.
      expect(serialized.includes(` ${word} `)).toBe(false);
    }
    expect(serialized).not.toContain(mnemonic);
    expect(serialized).not.toContain("correct horse battery");
    expect(vault.iterations).toBeGreaterThanOrEqual(600_000);
    expect(isVaultFile(JSON.parse(serialized))).toBe(true);
    expect(await decryptVault(vault, "correct horse battery")).toBe(mnemonic);
  });

  it("rejects a wrong password and tampered ciphertext", async () => {
    const vault = await encryptVault(address, mnemonic, "correct horse battery");
    await expect(decryptVault(vault, "wrong password!")).rejects.toThrow("Wrong password");
    const flipped = vault.ciphertext.startsWith("A") ? "B" : "A";
    const tampered = { ...vault, ciphertext: flipped + vault.ciphertext.slice(1) };
    await expect(decryptVault(tampered, "correct horse battery")).rejects.toThrow();
  });

  it("uses a fresh salt and IV for every encryption", async () => {
    const a = await encryptVault(address, mnemonic, "same password 123");
    const b = await encryptVault(address, mnemonic, "same password 123");
    expect(a.salt).not.toBe(b.salt);
    expect(a.iv).not.toBe(b.iv);
    expect(a.ciphertext).not.toBe(b.ciphertext);
  });
});
