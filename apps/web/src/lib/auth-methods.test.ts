import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { beforeAll, describe, expect, it, vi } from "vitest";
import { english, generateMnemonic, mnemonicToAccount } from "viem/accounts";

// Minimal cookie jar standing in for next/headers so route handlers can be called directly.
const jar = new Map<string, string>();
vi.mock("next/headers", () => ({
  cookies: async () => ({
    get: (name: string) => (jar.has(name) ? { name, value: jar.get(name)! } : undefined),
    getAll: () => [...jar].map(([name, value]) => ({ name, value })),
    set: (name: string, value: string) => void jar.set(name, value),
  }),
}));

function absorbCookies(res: Response) {
  for (const raw of res.headers.getSetCookie()) {
    const [pair] = raw.split(";");
    const idx = pair!.indexOf("=");
    const name = pair!.slice(0, idx);
    const value = decodeURIComponent(pair!.slice(idx + 1));
    if (value === "") jar.delete(name);
    else jar.set(name, value);
  }
}

const HOST = "consinzo.test";
const req = (url: string, init?: RequestInit) =>
  new Request(`https://${HOST}${url}`, {
    ...init,
    headers: { host: HOST, "content-type": "application/json", ...(init?.headers ?? {}) },
  });
const post = (url: string, body: unknown) =>
  req(url, { method: "POST", body: JSON.stringify(body) });

beforeAll(() => {
  process.env.CONSINZO_DATA_DIR = fs.mkdtempSync(path.join(os.tmpdir(), "consinzo-auth-"));
  process.env.CONSINZO_AUTH_SECRET = "test-secret-for-auth-methods-suite-0123456789";
  delete process.env.NEXT_PUBLIC_SUPABASE_URL;
});

describe("Wallet sign-in (EIP-4361)", () => {
  const account = mnemonicToAccount(generateMnemonic(english));

  async function getMessage(address = account.address) {
    const { GET } = await import("@/app/api/v1/auth/wallet/nonce/route");
    const res = await GET(req(`/api/v1/auth/wallet/nonce?address=${address}`));
    absorbCookies(res);
    return ((await res.json()) as { message: string }).message;
  }

  it("creates an account from a valid signature and stores only the public address", async () => {
    jar.clear();
    const message = await getMessage();
    expect(message).toContain(`${HOST} wants you to sign in with your Ethereum account`);
    const signature = await account.signMessage({ message });

    const { POST } = await import("@/app/api/v1/auth/wallet/verify/route");
    const res = await POST(post("/api/v1/auth/wallet/verify", { message, signature }));
    expect(res.status).toBe(201);
    absorbCookies(res);
    const json = (await res.json()) as { walletAddress: string; created: boolean };
    expect(json.walletAddress).toBe(account.address);
    expect(jar.has("consinzo_session")).toBe(true);
    expect(jar.has("consinzo_wallet_nonce")).toBe(false);

    const { GET: me } = await import("@/app/api/v1/auth/me/route");
    const meJson = (await (await me()).json()) as {
      user: { walletAddress: string; email: string; authProvider: string };
    };
    expect(meJson.user.walletAddress).toBe(account.address);
    expect(meJson.user.authProvider).toBe("wallet");

    const dbFile = path.join(process.env.CONSINZO_DATA_DIR!, "consinzo-db.json");
    const dbText = fs.readFileSync(dbFile, "utf8");
    expect(dbText).toContain(account.address);
    expect(dbText).not.toMatch(/mnemonic|privateKey/i);
  });

  it("signs the same wallet back in to the same account", async () => {
    jar.clear();
    const message = await getMessage();
    const signature = await account.signMessage({ message });
    const { POST } = await import("@/app/api/v1/auth/wallet/verify/route");
    const res = await POST(post("/api/v1/auth/wallet/verify", { message, signature }));
    expect(res.status).toBe(200);
    expect(((await res.json()) as { created: boolean }).created).toBe(false);
  });

  it("rejects a signature from a different wallet", async () => {
    jar.clear();
    const message = await getMessage();
    const attacker = mnemonicToAccount(generateMnemonic(english));
    const signature = await attacker.signMessage({ message });
    const { POST } = await import("@/app/api/v1/auth/wallet/verify/route");
    const res = await POST(post("/api/v1/auth/wallet/verify", { message, signature }));
    expect(res.status).toBe(401);
    expect(jar.has("consinzo_session")).toBe(false);
  });

  it("rejects a replayed message once its nonce has been used", async () => {
    jar.clear();
    const message = await getMessage();
    const signature = await account.signMessage({ message });
    const { POST } = await import("@/app/api/v1/auth/wallet/verify/route");
    absorbCookies(await POST(post("/api/v1/auth/wallet/verify", { message, signature })));
    jar.delete("consinzo_session");
    const replay = await POST(post("/api/v1/auth/wallet/verify", { message, signature }));
    expect(replay.status).toBe(401);
  });

  it("rejects a message whose text was changed after the nonce was issued", async () => {
    jar.clear();
    const message = (await getMessage()).replace(HOST, "evil.example");
    const signature = await account.signMessage({ message });
    const { POST } = await import("@/app/api/v1/auth/wallet/verify/route");
    const res = await POST(post("/api/v1/auth/wallet/verify", { message, signature }));
    expect(res.status).toBe(401);
  });
});

describe("One-time codes (local development mode)", () => {
  it("signs in by email code, single use", async () => {
    jar.clear();
    const { POST: start } = await import("@/app/api/v1/auth/otp/start/route");
    const { POST: verify } = await import("@/app/api/v1/auth/otp/verify/route");
    const target = { channel: "email", identifier: "Dev.User@Example.com" };

    const started = (await (await start(post("/api/v1/auth/otp/start", target))).json()) as {
      devCode: string;
    };
    expect(started.devCode).toMatch(/^\d{6}$/);

    const wrong = started.devCode === "000000" ? "000001" : "000000";
    expect((await verify(post("/x", { ...target, code: wrong }))).status).toBe(401);

    const ok = await verify(post("/x", { ...target, code: started.devCode }));
    expect(ok.status).toBe(201);
    absorbCookies(ok);
    expect(jar.has("consinzo_session")).toBe(true);

    expect((await verify(post("/x", { ...target, code: started.devCode }))).status).toBe(401);
  });

  it("signs in by phone code and rejects badly formatted numbers", async () => {
    jar.clear();
    const { POST: start } = await import("@/app/api/v1/auth/otp/start/route");
    const { POST: verify } = await import("@/app/api/v1/auth/otp/verify/route");

    expect((await start(post("/x", { channel: "phone", identifier: "5551234" }))).status).toBe(400);

    const target = { channel: "phone", identifier: "+1 (415) 555-2671" };
    const started = (await (await start(post("/x", target))).json()) as { devCode: string };
    const ok = await verify(post("/x", { ...target, code: started.devCode }));
    expect(ok.status).toBe(201);
    absorbCookies(ok);

    const { GET: me } = await import("@/app/api/v1/auth/me/route");
    const meJson = (await (await me()).json()) as { user: { phone: string } };
    expect(meJson.user.phone).not.toContain("5552671");
    expect(meJson.user.phone.endsWith("71")).toBe(true);
  });

  it("locks a code after five wrong attempts", async () => {
    jar.clear();
    const { POST: start } = await import("@/app/api/v1/auth/otp/start/route");
    const { POST: verify } = await import("@/app/api/v1/auth/otp/verify/route");
    const target = { channel: "email", identifier: "lockout@example.com" };
    const { devCode } = (await (await start(post("/x", target))).json()) as { devCode: string };
    const wrong = devCode === "111111" ? "222222" : "111111";
    for (let i = 0; i < 5; i++) await verify(post("/x", { ...target, code: wrong }));
    expect((await verify(post("/x", { ...target, code: devCode }))).status).toBe(401);
  });
});

describe("Method availability", () => {
  it("never offers Google or GitHub without Supabase, and reports dev codes honestly", async () => {
    const { getAuthMethodAvailability, safeNextPath } = await import("@/lib/auth-methods");
    const m = getAuthMethodAvailability();
    expect(m).toMatchObject({ wallet: true, password: true, google: false, github: false });
    expect(m.mode).toBe("local");
    expect(safeNextPath("//evil.example")).toBe("/dashboard");
    expect(safeNextPath("https://evil.example")).toBe("/dashboard");
    expect(safeNextPath("/workspace/erc20-token-vault")).toBe("/workspace/erc20-token-vault");
  });
});
