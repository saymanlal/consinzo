"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Github, KeyRound, Loader2, Mail, Smartphone, UserRound, Wallet } from "lucide-react";
import { WalletCreateFlow } from "@/components/wallet-create-flow";
import {
  getInjectedProvider,
  shortAddress,
  signInWithInjectedWallet,
  signInWithMnemonic,
  WalletError,
} from "@/lib/wallet-client";
import { decryptVault, listVaults, type WalletVault } from "@/lib/wallet-vault";

interface Methods {
  password: boolean;
  wallet: boolean;
  google: boolean;
  github: boolean;
  emailCode: boolean;
  phone: boolean;
  devCodes: boolean;
  mode: "supabase" | "local";
}

type Tab = "password" | "email-code" | "phone";
type View = "methods" | "create-wallet" | "saved-wallet";

const FIELD =
  "cz-focus w-full rounded-xl border border-white/10 bg-white/[0.04] px-3.5 py-2.5 text-sm text-white placeholder:text-zinc-600 focus:border-cyan-400/60";
const METHOD_BTN =
  "cz-focus flex w-full cursor-pointer items-center justify-center gap-2.5 rounded-xl border border-white/12 bg-white/[0.04] px-4 py-3 text-sm font-medium text-white transition hover:border-white/30 hover:bg-white/[0.08] disabled:cursor-not-allowed disabled:opacity-50";

const CALLBACK_ERRORS: Record<string, string> = {
  provider_unavailable: "That sign-in method is not enabled on this deployment.",
  unknown_provider: "Unknown sign-in provider.",
  oauth_start_failed: "Could not reach the sign-in provider. Try again.",
  access_denied: "Sign-in was cancelled.",
  callback_failed: "Sign-in could not be completed. Try again.",
  link_expired: "That sign-in link has expired. Request a new one.",
  profile_failed: "You are signed in, but your profile could not be created. Contact support.",
};

function GoogleIcon() {
  return (
    <svg viewBox="0 0 24 24" className="h-4 w-4" aria-hidden>
      <path fill="#4285F4" d="M23.5 12.3c0-.8-.1-1.6-.2-2.3H12v4.4h6.5a5.6 5.6 0 0 1-2.4 3.6v3h3.9c2.3-2.1 3.5-5.2 3.5-8.7Z" />
      <path fill="#34A853" d="M12 24c3.2 0 6-1.1 8-2.9l-3.9-3c-1.1.7-2.5 1.2-4.1 1.2-3.1 0-5.8-2.1-6.7-5H1.3v3.1A12 12 0 0 0 12 24Z" />
      <path fill="#FBBC05" d="M5.3 14.3a7.2 7.2 0 0 1 0-4.6V6.6H1.3a12 12 0 0 0 0 10.8l4-3.1Z" />
      <path fill="#EA4335" d="M12 4.8c1.8 0 3.3.6 4.6 1.8L20 3.1A12 12 0 0 0 1.3 6.6l4 3.1c.9-2.9 3.6-4.9 6.7-4.9Z" />
    </svg>
  );
}

export function AuthPanel() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const queryClient = useQueryClient();

  const rawNext = searchParams.get("next") ?? "";
  const next = rawNext.startsWith("/") && !rawNext.startsWith("//") ? rawNext : "/dashboard";
  const [mode, setMode] = useState<"login" | "register">(
    searchParams.get("mode") === "register" ? "register" : "login"
  );
  const [view, setView] = useState<View>("methods");
  const [tab, setTab] = useState<Tab>("password");
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(
    CALLBACK_ERRORS[searchParams.get("error") ?? ""] ?? null
  );

  // password
  const [email, setEmail] = useState("");
  const [username, setUsername] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [password, setPassword] = useState("");
  // one-time code
  const [identifier, setIdentifier] = useState("");
  const [code, setCode] = useState("");
  const [codeSentTo, setCodeSentTo] = useState<string | null>(null);
  const [devCode, setDevCode] = useState<string | null>(null);
  // saved wallet
  const [vaults, setVaults] = useState<WalletVault[]>([]);
  const [vaultPassword, setVaultPassword] = useState("");
  const [hasInjected, setHasInjected] = useState(false);

  useEffect(() => {
    setVaults(listVaults());
    setHasInjected(Boolean(getInjectedProvider()));
  }, []);

  const { data } = useQuery<{ methods: Methods }>({
    queryKey: ["auth-providers"],
    queryFn: async () => (await fetch("/api/v1/auth/providers")).json(),
    staleTime: 60_000,
  });
  const methods = data?.methods;

  async function completeSignIn() {
    await queryClient.invalidateQueries({ queryKey: ["auth-me"] });
    router.push(next);
    router.refresh();
  }

  async function run(label: string, fn: () => Promise<void>) {
    setError(null);
    setBusy(label);
    try {
      await fn();
    } catch (e) {
      setError(
        e instanceof WalletError || e instanceof Error ? e.message : "Something went wrong."
      );
    } finally {
      setBusy(null);
    }
  }

  async function postJson(url: string, body: unknown) {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const json = await res.json().catch(() => null);
    if (!res.ok) {
      const fields = json?.error?.details?.fieldErrors as Record<string, string[]> | undefined;
      const firstField = fields ? Object.values(fields).flat()[0] : undefined;
      throw new Error(firstField ?? json?.error?.message ?? "Request failed.");
    }
    return json;
  }

  const submitPassword = (e: React.FormEvent) => {
    e.preventDefault();
    void run("password", async () => {
      await postJson(
        mode === "login" ? "/api/v1/auth/login" : "/api/v1/auth/register",
        mode === "login" ? { email, password } : { email, username, displayName, password }
      );
      await completeSignIn();
    });
  };

  const channel = tab === "phone" ? "phone" : "email";
  const sendCode = (e: React.FormEvent) => {
    e.preventDefault();
    void run("code", async () => {
      const json = await postJson("/api/v1/auth/otp/start", { channel, identifier, next });
      setCodeSentTo(identifier);
      setDevCode(json?.devCode ?? null);
      setCode("");
    });
  };
  const verifyCode = (e: React.FormEvent) => {
    e.preventDefault();
    void run("code", async () => {
      await postJson("/api/v1/auth/otp/verify", { channel, identifier: codeSentTo, code });
      await completeSignIn();
    });
  };

  const connectWallet = () =>
    run("wallet", async () => {
      await signInWithInjectedWallet();
      await completeSignIn();
    });

  const unlockSavedWallet = (vault: WalletVault) => (e: React.FormEvent) => {
    e.preventDefault();
    void run("saved-wallet", async () => {
      const mnemonic = await decryptVault(vault, vaultPassword);
      await signInWithMnemonic(mnemonic);
      setVaultPassword("");
      await completeSignIn();
    });
  };

  function switchTab(t: Tab) {
    setTab(t);
    setError(null);
    setCodeSentTo(null);
    setDevCode(null);
    setIdentifier("");
    setCode("");
  }

  const tabs: Array<{ id: Tab; label: string; icon: typeof Mail; show: boolean }> = [
    { id: "password", label: "Password", icon: KeyRound, show: true },
    { id: "email-code", label: "Email code", icon: Mail, show: Boolean(methods?.emailCode) },
    { id: "phone", label: "Phone", icon: Smartphone, show: Boolean(methods?.phone) },
  ];

  return (
    <div className="cz-card p-6 sm:p-8">
      {view === "create-wallet" ? (
        <WalletCreateFlow onDone={completeSignIn} onCancel={() => setView("methods")} />
      ) : view === "saved-wallet" ? (
        <div>
          <button
            type="button"
            onClick={() => {
              setView("methods");
              setError(null);
            }}
            className="cz-focus cursor-pointer rounded text-xs text-zinc-400 hover:text-white"
          >
            ← Other sign-in options
          </button>
          <h2 className="mt-4 text-xl font-semibold text-white">Wallet saved on this device</h2>
          <p className="mt-2 text-sm text-zinc-400">
            Enter the wallet password you chose when you created it. It is checked on this
            device and never sent to us.
          </p>
          {vaults.map((v) => (
            <form key={v.address} onSubmit={unlockSavedWallet(v)} className="mt-5 space-y-3">
              <p className="font-mono text-xs text-zinc-300">{shortAddress(v.address)}</p>
              <input
                type="password"
                autoComplete="current-password"
                required
                value={vaultPassword}
                onChange={(e) => setVaultPassword(e.target.value)}
                placeholder="Wallet password"
                aria-label="Wallet password"
                className={FIELD}
              />
              <button type="submit" disabled={busy !== null} className="cz-btn cz-btn-primary w-full disabled:opacity-60">
                {busy === "saved-wallet" && <Loader2 className="h-4 w-4 animate-spin" />}
                Unlock and sign in
              </button>
            </form>
          ))}
        </div>
      ) : (
        <>
          <h2 className="text-2xl font-semibold tracking-tight text-white">
            {mode === "login" ? "Welcome back" : "Create your account"}
          </h2>
          <p className="mt-1.5 text-sm text-zinc-400">
            {mode === "login"
              ? "Sign in to keep your scores and badges."
              : "Pick any method. You can start solving in under a minute."}
          </p>

          <div role="tablist" aria-label="Sign in or register" className="mt-5 grid grid-cols-2 rounded-xl border border-white/10 bg-white/[0.03] p-1 text-sm font-medium">
            {(["login", "register"] as const).map((m) => (
              <button
                key={m}
                type="button"
                role="tab"
                aria-selected={mode === m}
                onClick={() => {
                  setMode(m);
                  setError(null);
                }}
                className={`cz-focus cursor-pointer rounded-lg py-2 transition ${
                  mode === m ? "bg-white text-zinc-950" : "text-zinc-400 hover:text-white"
                }`}
              >
                {m === "login" ? "Sign in" : "Register"}
              </button>
            ))}
          </div>

          <div className="mt-5 space-y-2.5">
            <button type="button" onClick={connectWallet} disabled={busy !== null} className={METHOD_BTN}>
              {busy === "wallet" ? <Loader2 className="h-4 w-4 animate-spin" /> : <Wallet className="h-4 w-4 text-cyan-300" />}
              {hasInjected ? "Continue with wallet" : "Connect a browser wallet"}
            </button>
            {vaults.length > 0 && (
              <button type="button" onClick={() => setView("saved-wallet")} disabled={busy !== null} className={METHOD_BTN}>
                <KeyRound className="h-4 w-4 text-violet-300" />
                Use the wallet saved on this device
              </button>
            )}
            {methods?.google && (
              <a href={`/api/v1/auth/oauth/google?next=${encodeURIComponent(next)}`} className={METHOD_BTN}>
                <GoogleIcon />
                Continue with Google
              </a>
            )}
            {methods?.github && (
              <a href={`/api/v1/auth/oauth/github?next=${encodeURIComponent(next)}`} className={METHOD_BTN}>
                <Github className="h-4 w-4" />
                Continue with GitHub
              </a>
            )}
            <p className="pt-1 text-center text-xs text-zinc-500">
              No wallet yet?{" "}
              <button
                type="button"
                onClick={() => {
                  setView("create-wallet");
                  setError(null);
                }}
                className="cz-focus cursor-pointer rounded font-medium text-cyan-300 underline-offset-2 hover:underline"
              >
                Create one in 30 seconds
              </button>
            </p>
          </div>

          <div className="my-6 flex items-center gap-3 text-[11px] uppercase tracking-widest text-zinc-600">
            <span className="h-px flex-1 bg-white/10" />
            or
            <span className="h-px flex-1 bg-white/10" />
          </div>

          {tabs.filter((t) => t.show).length > 1 && (
            <div role="tablist" aria-label="Sign-in method" className="mb-4 flex gap-1.5">
              {tabs
                .filter((t) => t.show)
                .map((t) => (
                  <button
                    key={t.id}
                    type="button"
                    role="tab"
                    aria-selected={tab === t.id}
                    onClick={() => switchTab(t.id)}
                    className={`cz-focus inline-flex flex-1 cursor-pointer items-center justify-center gap-1.5 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                      tab === t.id
                        ? "border-cyan-400/50 bg-cyan-400/10 text-white"
                        : "border-white/10 text-zinc-400 hover:text-white"
                    }`}
                  >
                    <t.icon className="h-3.5 w-3.5" />
                    {t.label}
                  </button>
                ))}
            </div>
          )}

          {tab === "password" && (
            <form onSubmit={submitPassword} className="space-y-3.5">
              <label className="block text-xs font-medium text-zinc-300">
                Email
                <input type="email" required autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@example.com" className={`${FIELD} mt-1.5`} />
              </label>
              {mode === "register" && (
                <div className="grid gap-3.5 sm:grid-cols-2">
                  <label className="block text-xs font-medium text-zinc-300">
                    Username
                    <input required pattern="[a-zA-Z0-9_\-]{3,32}" title="3 to 32 letters, numbers, _ or -" autoComplete="username" value={username} onChange={(e) => setUsername(e.target.value)} placeholder="sol_architect" className={`${FIELD} mt-1.5`} />
                  </label>
                  <label className="block text-xs font-medium text-zinc-300">
                    Display name
                    <input required minLength={2} maxLength={60} autoComplete="name" value={displayName} onChange={(e) => setDisplayName(e.target.value)} placeholder="Alex Rivera" className={`${FIELD} mt-1.5`} />
                  </label>
                </div>
              )}
              <label className="block text-xs font-medium text-zinc-300">
                Password
                <input type="password" required minLength={mode === "register" ? 8 : 1} autoComplete={mode === "login" ? "current-password" : "new-password"} value={password} onChange={(e) => setPassword(e.target.value)} placeholder={mode === "register" ? "At least 8 characters" : ""} className={`${FIELD} mt-1.5`} />
              </label>
              <button type="submit" disabled={busy !== null} className="cz-btn cz-btn-primary w-full disabled:opacity-60">
                {busy === "password" && <Loader2 className="h-4 w-4 animate-spin" />}
                {mode === "login" ? "Sign in" : "Create account"}
              </button>
            </form>
          )}

          {tab !== "password" &&
            (codeSentTo ? (
              <form onSubmit={verifyCode} className="space-y-3.5">
                <p className="text-sm text-zinc-400">
                  Enter the 6-digit code sent to <span className="break-all text-white">{codeSentTo}</span>.
                </p>
                {devCode && (
                  <p className="rounded-xl border border-amber-400/30 bg-amber-400/10 px-3.5 py-2.5 text-xs text-amber-100">
                    Development mode: no message was sent. Your code is{" "}
                    <span className="font-mono text-sm font-semibold">{devCode}</span>.
                  </p>
                )}
                <input inputMode="numeric" autoComplete="one-time-code" required pattern="\d{6}" maxLength={6} value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))} placeholder="000000" aria-label="6-digit code" className={`${FIELD} text-center font-mono text-lg tracking-[0.5em]`} />
                <button type="submit" disabled={busy !== null || code.length !== 6} className="cz-btn cz-btn-primary w-full disabled:opacity-60">
                  {busy === "code" && <Loader2 className="h-4 w-4 animate-spin" />}
                  Verify and continue
                </button>
                <button type="button" onClick={() => setCodeSentTo(null)} className="cz-focus w-full cursor-pointer rounded text-xs text-zinc-400 hover:text-white">
                  Use a different {tab === "phone" ? "number" : "email"}
                </button>
              </form>
            ) : (
              <form onSubmit={sendCode} className="space-y-3.5">
                <label className="block text-xs font-medium text-zinc-300">
                  {tab === "phone" ? "Mobile number" : "Email"}
                  <input
                    type={tab === "phone" ? "tel" : "email"}
                    required
                    autoComplete={tab === "phone" ? "tel" : "email"}
                    value={identifier}
                    onChange={(e) => setIdentifier(e.target.value)}
                    placeholder={tab === "phone" ? "+14155552671" : "you@example.com"}
                    className={`${FIELD} mt-1.5`}
                  />
                </label>
                <p className="text-xs text-zinc-500">
                  {tab === "phone"
                    ? "Include the country code. We text you a one-time code; no password needed."
                    : "We email you a one-time code; no password needed."}{" "}
                  New here? This creates your account.
                </p>
                <button type="submit" disabled={busy !== null} className="cz-btn cz-btn-primary w-full disabled:opacity-60">
                  {busy === "code" && <Loader2 className="h-4 w-4 animate-spin" />}
                  Send code
                </button>
              </form>
            ))}
        </>
      )}

      {error && view !== "create-wallet" && (
        <p role="alert" className="mt-4 rounded-xl border border-rose-400/30 bg-rose-400/10 px-3.5 py-2.5 text-xs text-rose-200">
          {error}
        </p>
      )}

      {view === "methods" && (
        <div className="mt-6 border-t border-white/10 pt-5 text-center">
          <Link href="/challenges" className="cz-focus inline-flex items-center gap-2 rounded text-sm font-medium text-zinc-300 hover:text-white">
            <UserRound className="h-4 w-4" />
            Continue as guest
          </Link>
          <p className="mt-1.5 text-xs text-zinc-500">
            Run public tests without an account. Scores and badges need one.
          </p>
        </div>
      )}
    </div>
  );
}
