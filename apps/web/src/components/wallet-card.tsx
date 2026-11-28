"use client";

import React, { useEffect, useState } from "react";
import { Check, Copy, Download, KeyRound, Lock, ShieldCheck, Trash2, Wallet } from "lucide-react";
import { SecretPhrase } from "@/components/secret-phrase";
import { shortAddress } from "@/lib/wallet-client";
import {
  decryptVault,
  downloadVault,
  getVault,
  removeVault,
  type WalletVault,
} from "@/lib/wallet-vault";

const BTN =
  "inline-flex cursor-pointer items-center gap-1.5 rounded-md border border-zinc-300 bg-white px-3 py-1.5 text-xs font-medium text-zinc-800 hover:bg-zinc-50 disabled:opacity-50";

/**
 * Profile section for a wallet-linked account. The address is public. The recovery phrase
 * is only available if this browser holds the encrypted copy, and only after the wallet
 * password decrypts it locally; it is shown blurred and re-hides on a timer.
 */
export function WalletCard({ address }: { address: string }) {
  const [vault, setVault] = useState<WalletVault | null>(null);
  const [copied, setCopied] = useState(false);
  const [showFull, setShowFull] = useState(false);
  const [unlocking, setUnlocking] = useState(false);
  const [password, setPassword] = useState("");
  const [phrase, setPhrase] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [confirmRemove, setConfirmRemove] = useState(false);

  useEffect(() => {
    setVault(getVault(address));
  }, [address]);

  // Drop the decrypted phrase from memory two minutes after it was unlocked.
  useEffect(() => {
    if (!phrase) return;
    const t = setTimeout(() => setPhrase(null), 120_000);
    return () => clearTimeout(t);
  }, [phrase]);

  async function copyAddress() {
    try {
      await navigator.clipboard.writeText(address);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      /* ignore */
    }
  }

  async function unlock(e: React.FormEvent) {
    e.preventDefault();
    if (!vault) return;
    setError(null);
    try {
      setPhrase(await decryptVault(vault, password));
      setUnlocking(false);
    } catch {
      setError("That wallet password is not correct.");
    } finally {
      setPassword("");
    }
  }

  return (
    <section aria-labelledby="wallet-heading" className="rounded-lg border border-zinc-200 bg-white p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h2 id="wallet-heading" className="flex items-center gap-2 text-sm font-semibold text-zinc-950">
          <Wallet className="h-4 w-4 text-blue-700" />
          Wallet
        </h2>
        <span className="inline-flex items-center gap-1.5 rounded-full border border-emerald-200 bg-emerald-50 px-2.5 py-0.5 text-[11px] font-medium text-emerald-800">
          <ShieldCheck className="h-3 w-3" />
          Ownership verified by signature
        </span>
      </div>

      <div className="mt-4 rounded-md border border-zinc-200 bg-zinc-50 p-3">
        <p className="text-[11px] uppercase tracking-wider text-zinc-500">Address (public)</p>
        <div className="mt-1 flex flex-wrap items-center gap-2">
          <code className="break-all font-mono text-xs text-zinc-900">
            {showFull ? address : shortAddress(address)}
          </code>
          <button type="button" onClick={() => setShowFull((s) => !s)} className="cursor-pointer text-[11px] font-medium text-blue-700 hover:underline">
            {showFull ? "Shorten" : "Show full"}
          </button>
          <button type="button" onClick={copyAddress} className={BTN} aria-label="Copy wallet address">
            {copied ? <Check className="h-3.5 w-3.5" /> : <Copy className="h-3.5 w-3.5" />}
            {copied ? "Copied" : "Copy"}
          </button>
        </div>
      </div>

      <div className="mt-4">
        <p className="flex items-center gap-2 text-xs font-medium text-zinc-900">
          <Lock className="h-3.5 w-3.5 text-zinc-500" />
          Recovery phrase
        </p>
        {!vault ? (
          <p className="mt-1.5 text-xs leading-relaxed text-zinc-600">
            CONSINZO does not hold your recovery phrase, and there is no encrypted copy in this
            browser. It lives in your own wallet app or wherever you wrote it down.
          </p>
        ) : phrase ? (
          <div className="mt-3">
            <SecretPhrase mnemonic={phrase} surface="light" />
            <button type="button" onClick={() => setPhrase(null)} className={`${BTN} mt-3`}>
              <Lock className="h-3.5 w-3.5" /> Lock again
            </button>
          </div>
        ) : (
          <>
            <p className="mt-1.5 text-xs leading-relaxed text-zinc-600">
              Hidden. An encrypted copy is stored in this browser only. Unlock it with your
              wallet password to view the 12 words. We never see the phrase or the password.
            </p>
            {unlocking ? (
              <form onSubmit={unlock} className="mt-3 flex flex-wrap gap-2">
                <input
                  type="password"
                  required
                  autoFocus
                  autoComplete="current-password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Wallet password"
                  aria-label="Wallet password"
                  className="h-9 min-w-0 flex-1 rounded-md border border-zinc-300 px-3 text-sm focus:border-slate-900 focus:outline-none"
                />
                <button type="submit" className="inline-flex h-9 cursor-pointer items-center rounded-md bg-slate-900 px-4 text-xs font-medium text-white hover:bg-slate-800">
                  Unlock
                </button>
                <button type="button" onClick={() => { setUnlocking(false); setError(null); }} className={BTN}>
                  Cancel
                </button>
              </form>
            ) : (
              <div className="mt-3 flex flex-wrap gap-2">
                <button type="button" onClick={() => setUnlocking(true)} className={BTN}>
                  <KeyRound className="h-3.5 w-3.5" /> Unlock to view
                </button>
                <button type="button" onClick={() => downloadVault(vault)} className={BTN}>
                  <Download className="h-3.5 w-3.5" /> Download encrypted backup
                </button>
                {confirmRemove ? (
                  <>
                    <button
                      type="button"
                      onClick={() => { removeVault(address); setVault(null); setConfirmRemove(false); }}
                      className="inline-flex cursor-pointer items-center gap-1.5 rounded-md border border-red-700 bg-red-700 px-3 py-1.5 text-xs font-medium text-white hover:bg-red-800"
                    >
                      Yes, remove from this browser
                    </button>
                    <button type="button" onClick={() => setConfirmRemove(false)} className={BTN}>
                      Keep it
                    </button>
                  </>
                ) : (
                  <button type="button" onClick={() => setConfirmRemove(true)} className={BTN}>
                    <Trash2 className="h-3.5 w-3.5" /> Remove from this browser
                  </button>
                )}
              </div>
            )}
            {confirmRemove && (
              <p className="mt-2 text-[11px] text-red-700">
                Only do this if you have the 12 words saved elsewhere. Removing the copy cannot be undone.
              </p>
            )}
            {error && <p role="alert" className="mt-2 text-xs text-red-700">{error}</p>}
          </>
        )}
      </div>
    </section>
  );
}
