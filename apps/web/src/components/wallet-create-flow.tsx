"use client";

import React, { useState } from "react";
import { AlertTriangle, ArrowLeft, Download, Loader2, ShieldCheck, Sparkles } from "lucide-react";
import { SecretPhrase } from "@/components/secret-phrase";
import { generateWallet, signInWithMnemonic, WalletError } from "@/lib/wallet-client";
import { downloadVault, encryptVault, saveVault, type WalletVault } from "@/lib/wallet-vault";

const FIELD =
  "cz-focus w-full rounded-xl border border-white/10 bg-white/[0.04] px-3.5 py-2.5 text-sm text-white placeholder:text-zinc-600 focus:border-cyan-400/60";

/**
 * Creates a wallet for someone who does not have one, then registers with it.
 * Everything sensitive happens in this component's memory: the phrase is generated in the
 * browser, shown once behind a reveal, optionally encrypted to this device, and dropped
 * when the flow ends. The server only ever sees the public address and a signature.
 */
export function WalletCreateFlow({
  onDone,
  onCancel,
}: {
  onDone: () => void;
  onCancel: () => void;
}) {
  const [step, setStep] = useState<"intro" | "phrase" | "protect">("intro");
  const [wallet, setWallet] = useState<{ mnemonic: string; address: string } | null>(null);
  const [saved, setSaved] = useState(false);
  const [keepCopy, setKeepCopy] = useState(true);
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [vault, setVault] = useState<WalletVault | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function generate() {
    setBusy(true);
    setError(null);
    try {
      setWallet(await generateWallet());
      setStep("phrase");
    } catch {
      setError("Could not generate a wallet in this browser.");
    } finally {
      setBusy(false);
    }
  }

  async function finish() {
    if (!wallet) return;
    setError(null);
    if (keepCopy) {
      if (password.length < 10) return setError("Use a password of at least 10 characters.");
      if (password !== confirm) return setError("The two passwords do not match.");
    }
    setBusy(true);
    try {
      if (keepCopy) {
        const v = vault ?? (await encryptVault(wallet.address, wallet.mnemonic, password));
        saveVault(v);
        setVault(v);
      }
      await signInWithMnemonic(wallet.mnemonic);
      setWallet(null);
      setPassword("");
      setConfirm("");
      onDone();
    } catch (e) {
      setError(e instanceof WalletError ? e.message : "Could not finish creating the account.");
    } finally {
      setBusy(false);
    }
  }

  async function backup() {
    if (!wallet) return;
    if (password.length < 10 || password !== confirm) {
      return setError("Set and confirm a password of at least 10 characters first.");
    }
    setError(null);
    const v = vault ?? (await encryptVault(wallet.address, wallet.mnemonic, password));
    setVault(v);
    downloadVault(v);
  }

  return (
    <div>
      <button
        type="button"
        onClick={step === "protect" ? () => setStep("phrase") : onCancel}
        className="cz-focus inline-flex cursor-pointer items-center gap-1.5 rounded text-xs text-zinc-400 hover:text-white"
      >
        <ArrowLeft className="h-3.5 w-3.5" />
        {step === "protect" ? "Back to phrase" : "Other sign-in options"}
      </button>

      <ol className="mt-4 flex gap-1.5" aria-label="Progress">
        {(["intro", "phrase", "protect"] as const).map((s, i) => (
          <li
            key={s}
            aria-current={step === s ? "step" : undefined}
            className={`h-1 flex-1 rounded-full ${
              i <= ["intro", "phrase", "protect"].indexOf(step) ? "bg-cyan-400" : "bg-white/10"
            }`}
          />
        ))}
      </ol>

      {step === "intro" && (
        <div className="mt-5">
          <h2 className="text-xl font-semibold text-white">Create a wallet</h2>
          <p className="mt-2 text-sm leading-relaxed text-zinc-400">
            No wallet yet? We will make one for you, on this device, in a few seconds.
          </p>
          <ul className="mt-4 space-y-3 text-sm text-zinc-300">
            <li className="flex gap-3">
              <ShieldCheck className="mt-0.5 h-4 w-4 shrink-0 text-emerald-400" />
              Generated in your browser. CONSINZO never receives your recovery phrase or private key.
            </li>
            <li className="flex gap-3">
              <Sparkles className="mt-0.5 h-4 w-4 shrink-0 text-cyan-300" />
              You get a standard 12-word phrase that also works in MetaMask and other wallets.
            </li>
            <li className="flex gap-3">
              <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0 text-amber-300" />
              Only you can recover it. If you lose the phrase, nobody, including us, can restore it.
            </li>
          </ul>
          <button type="button" onClick={generate} disabled={busy} className="cz-btn cz-btn-primary mt-6 w-full disabled:opacity-60">
            {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <Sparkles className="h-4 w-4" />}
            Generate my wallet
          </button>
        </div>
      )}

      {step === "phrase" && wallet && (
        <div className="mt-5">
          <h2 className="text-xl font-semibold text-white">Save your recovery phrase</h2>
          <p className="mt-2 text-sm leading-relaxed text-zinc-400">
            Write these 12 words down in order and keep them somewhere private. They are hidden
            until you choose to reveal them.
          </p>
          <div className="mt-4 rounded-xl border border-white/10 bg-white/[0.03] p-3">
            <p className="text-[11px] uppercase tracking-wider text-zinc-500">Your wallet address (public)</p>
            <p className="mt-1 break-all font-mono text-xs text-zinc-200">{wallet.address}</p>
          </div>
          <div className="mt-4">
            <SecretPhrase mnemonic={wallet.mnemonic} />
          </div>
          <label className="mt-5 flex cursor-pointer items-start gap-3 text-sm text-zinc-300">
            <input
              type="checkbox"
              checked={saved}
              onChange={(e) => setSaved(e.target.checked)}
              className="mt-0.5 h-4 w-4 accent-cyan-400"
            />
            I have written down my recovery phrase and understand it cannot be recovered for me.
          </label>
          <button
            type="button"
            disabled={!saved}
            onClick={() => setStep("protect")}
            className="cz-btn cz-btn-primary mt-5 w-full disabled:cursor-not-allowed disabled:opacity-40"
          >
            Continue
          </button>
        </div>
      )}

      {step === "protect" && wallet && (
        <div className="mt-5">
          <h2 className="text-xl font-semibold text-white">Protect it on this device</h2>
          <p className="mt-2 text-sm leading-relaxed text-zinc-400">
            Keep an encrypted copy in this browser so you can sign in again and view the phrase
            from your profile. It is locked with a password only you know.
          </p>
          <label className="mt-4 flex cursor-pointer items-start gap-3 text-sm text-zinc-300">
            <input
              type="checkbox"
              checked={keepCopy}
              onChange={(e) => setKeepCopy(e.target.checked)}
              className="mt-0.5 h-4 w-4 accent-cyan-400"
            />
            Keep an encrypted copy in this browser (recommended)
          </label>
          {keepCopy && (
            <div className="mt-4 space-y-3">
              <label className="block text-xs font-medium text-zinc-300">
                Wallet password
                <input
                  type="password"
                  autoComplete="new-password"
                  value={password}
                  onChange={(e) => {
                    setPassword(e.target.value);
                    setVault(null);
                  }}
                  placeholder="At least 10 characters"
                  className={`${FIELD} mt-1.5`}
                />
              </label>
              <label className="block text-xs font-medium text-zinc-300">
                Confirm password
                <input
                  type="password"
                  autoComplete="new-password"
                  value={confirm}
                  onChange={(e) => setConfirm(e.target.value)}
                  className={`${FIELD} mt-1.5`}
                />
              </label>
              <button type="button" onClick={backup} className="cz-btn cz-btn-ghost w-full text-xs">
                <Download className="h-3.5 w-3.5" />
                Download encrypted backup file
              </button>
              <p className="text-[11px] leading-relaxed text-zinc-500">
                This password is not your CONSINZO password and is never sent to us. If you
                forget it, use your 12 words instead.
              </p>
            </div>
          )}
          <button type="button" onClick={finish} disabled={busy} className="cz-btn cz-btn-primary mt-6 w-full disabled:opacity-60">
            {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : null}
            Create my account with this wallet
          </button>
        </div>
      )}

      {error && (
        <p role="alert" className="mt-4 rounded-xl border border-rose-400/30 bg-rose-400/10 px-3.5 py-2.5 text-xs text-rose-200">
          {error}
        </p>
      )}
    </div>
  );
}
