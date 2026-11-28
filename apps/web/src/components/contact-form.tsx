"use client";

import React, { useState } from "react";
import { CheckCircle2, Send } from "lucide-react";

const TOPICS = [
  { id: "general", label: "General question" },
  { id: "support", label: "Help with my account or a challenge" },
  { id: "partnership", label: "Partnership or sponsorship" },
  { id: "security", label: "Security report" },
  { id: "press", label: "Press" },
] as const;

const FIELD =
  "cz-focus w-full rounded-xl border border-white/10 bg-white/[0.04] px-3.5 py-2.5 text-sm text-white placeholder:text-zinc-600 focus:border-cyan-400/60";

export function ContactForm() {
  const [status, setStatus] = useState<"idle" | "sending" | "sent">("idle");
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget;
    const data = Object.fromEntries(new FormData(form).entries());
    setError(null);
    setStatus("sending");
    try {
      const res = await fetch("/api/v1/contact", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      });
      if (!res.ok) {
        const json = await res.json().catch(() => null);
        setError(
          json?.error?.code === "VALIDATION_ERROR"
            ? "Check the fields: a name, a valid email and a message of at least 10 characters."
            : (json?.error?.message ?? "Could not send your message. Try again.")
        );
        setStatus("idle");
        return;
      }
      form.reset();
      setStatus("sent");
    } catch {
      setError("Network error. Check your connection and try again.");
      setStatus("idle");
    }
  }

  if (status === "sent") {
    return (
      <div role="status" className="cz-card flex flex-col items-start gap-3 p-8">
        <CheckCircle2 className="h-8 w-8 text-emerald-400" />
        <h2 className="text-xl font-semibold text-white">Message received</h2>
        <p className="text-sm leading-relaxed text-zinc-400">
          Thanks for writing. Your message is saved for the team and we will reply to the email
          address you gave.
        </p>
        <button type="button" onClick={() => setStatus("idle")} className="cz-btn cz-btn-ghost mt-2">
          Send another
        </button>
      </div>
    );
  }

  return (
    <form onSubmit={onSubmit} className="cz-card space-y-5 p-6 sm:p-8" noValidate={false}>
      <div className="grid gap-5 sm:grid-cols-2">
        <label className="block text-xs font-medium text-zinc-300">
          Name
          <input name="name" required minLength={2} maxLength={80} autoComplete="name" className={`${FIELD} mt-1.5`} />
        </label>
        <label className="block text-xs font-medium text-zinc-300">
          Email
          <input name="email" type="email" required maxLength={160} autoComplete="email" className={`${FIELD} mt-1.5`} />
        </label>
      </div>
      <label className="block text-xs font-medium text-zinc-300">
        Topic
        <select name="topic" defaultValue="general" className={`${FIELD} mt-1.5 appearance-none`}>
          {TOPICS.map((t) => (
            <option key={t.id} value={t.id} className="bg-zinc-900">
              {t.label}
            </option>
          ))}
        </select>
      </label>
      <label className="block text-xs font-medium text-zinc-300">
        Message
        <textarea name="message" required minLength={10} maxLength={4000} rows={6} className={`${FIELD} mt-1.5 resize-y`} />
      </label>
      {/* Honeypot, hidden from people and assistive tech */}
      <div aria-hidden className="absolute left-[-9999px] h-0 w-0 overflow-hidden">
        <label>
          Company
          <input name="company" tabIndex={-1} autoComplete="off" />
        </label>
      </div>
      {error ? (
        <p role="alert" className="rounded-xl border border-rose-400/30 bg-rose-400/10 px-3.5 py-2.5 text-xs text-rose-200">
          {error}
        </p>
      ) : null}
      <button type="submit" disabled={status === "sending"} className="cz-btn cz-btn-primary w-full disabled:opacity-60 sm:w-auto">
        <Send className="h-4 w-4" />
        {status === "sending" ? "Sending…" : "Send message"}
      </button>
    </form>
  );
}
