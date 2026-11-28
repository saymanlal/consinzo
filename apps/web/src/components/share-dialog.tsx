"use client";

import React, { useEffect, useMemo, useRef, useState } from "react";
import { Check, Copy, ExternalLink, Link2, Share2, X } from "lucide-react";
import { AchievementMedal } from "@/components/achievement-badge";
import {
  buildCaption,
  buildShareTitle,
  CAPTION_TONES,
  SHARE_PLATFORMS,
  type CaptionTone,
  type SharePlatformId,
  type ShareSubject,
} from "@/lib/share";

/**
 * Share sheet with auto-drafted captions. Pick a network and a tone, edit the draft if
 * you like, then open the network's own composer with it filled in. Nothing is posted
 * by CONSINZO: the user always confirms on the network itself.
 */
export function ShareDialog({
  subject,
  badgeId,
  onClose,
}: {
  subject: ShareSubject;
  badgeId?: string;
  onClose: () => void;
}) {
  const [platformId, setPlatformId] = useState<SharePlatformId>("x");
  const [tone, setTone] = useState<CaptionTone>("proud");
  const [edited, setEdited] = useState<string | null>(null);
  const [copied, setCopied] = useState<"caption" | "link" | null>(null);
  const [canNativeShare, setCanNativeShare] = useState(false);
  const closeRef = useRef<HTMLButtonElement | null>(null);

  const url = useMemo(() => {
    const origin = typeof window === "undefined" ? "" : window.location.origin;
    return `${origin}/u/${subject.username}${badgeId ? `?badge=${badgeId}` : ""}`;
  }, [subject.username, badgeId]);

  const platform = SHARE_PLATFORMS.find((p) => p.id === platformId)!;
  const draft = useMemo(
    () => buildCaption(subject, platformId, tone, url),
    [subject, platformId, tone, url]
  );
  const caption = edited ?? draft;
  const title = buildShareTitle(subject);
  const used = caption.length + (platformId === "x" ? 24 : url.length + 1);
  const over = used > platform.limit;

  useEffect(() => {
    setCanNativeShare(typeof navigator !== "undefined" && typeof navigator.share === "function");
    closeRef.current?.focus();
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      window.removeEventListener("keydown", onKey);
      document.body.style.overflow = prev;
    };
  }, [onClose]);

  // A new network or tone means a fresh draft; drop manual edits.
  useEffect(() => setEdited(null), [platformId, tone]);

  async function copy(kind: "caption" | "link") {
    try {
      await navigator.clipboard.writeText(kind === "caption" ? `${caption}\n\n${url}` : url);
      setCopied(kind);
      setTimeout(() => setCopied(null), 2000);
    } catch {
      /* clipboard blocked: the text is still selectable in the box */
    }
  }

  const pill = (active: boolean) =>
    `cz-focus shrink-0 cursor-pointer rounded-full border px-3 py-1.5 text-xs font-medium transition ${
      active
        ? "border-cyan-400/60 bg-cyan-400/15 text-white"
        : "border-white/10 text-zinc-400 hover:border-white/25 hover:text-white"
    }`;

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-black/70 p-0 backdrop-blur-sm sm:items-center sm:p-4"
      onMouseDown={(e) => e.target === e.currentTarget && onClose()}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="share-title"
        className="cz-dark max-h-[92dvh] w-full max-w-lg overflow-y-auto rounded-t-2xl border border-white/10 p-5 shadow-2xl sm:rounded-2xl sm:p-6"
      >
        <div className="flex items-start justify-between gap-4">
          <div className="flex min-w-0 items-center gap-3">
            {badgeId ? <AchievementMedal id={badgeId} size="sm" /> : null}
            <div className="min-w-0">
              <h2 id="share-title" className="truncate text-base font-semibold text-white">
                {subject.badge ? `Share “${subject.badge.title}”` : "Share your profile"}
              </h2>
              <p className="text-xs text-zinc-500">Pick a network. We draft the caption; you post it.</p>
            </div>
          </div>
          <button
            ref={closeRef}
            type="button"
            onClick={onClose}
            aria-label="Close"
            className="cz-focus grid h-8 w-8 shrink-0 cursor-pointer place-items-center rounded-lg border border-white/10 text-zinc-400 hover:text-white"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        <div role="group" aria-label="Network" className="-mx-1 mt-5 flex gap-1.5 overflow-x-auto px-1 pb-1">
          {SHARE_PLATFORMS.map((p) => (
            <button key={p.id} type="button" aria-pressed={p.id === platformId} onClick={() => setPlatformId(p.id)} className={pill(p.id === platformId)}>
              {p.label}
            </button>
          ))}
        </div>

        {platformId === "reddit" ? (
          <div className="mt-4 rounded-xl border border-white/10 bg-black/40 p-3">
            <p className="text-[11px] uppercase tracking-wider text-zinc-500">Post title</p>
            <p className="mt-1 text-sm text-white">{title}</p>
            <p className="mt-2 text-xs text-zinc-500">Reddit posts are a title plus your link. Choose the community on Reddit.</p>
          </div>
        ) : (
          <>
            <div role="group" aria-label="Tone" className="mt-3 flex gap-1.5">
              {CAPTION_TONES.map((t) => (
                <button key={t.id} type="button" aria-pressed={t.id === tone} onClick={() => setTone(t.id)} className={pill(t.id === tone)}>
                  {t.label}
                </button>
              ))}
            </div>
            <label className="mt-4 block text-xs font-medium text-zinc-300">
              Caption draft
              <textarea
                value={caption}
                onChange={(e) => setEdited(e.target.value)}
                rows={7}
                className="cz-focus mt-1.5 w-full resize-y rounded-xl border border-white/10 bg-black/40 p-3 text-sm leading-relaxed text-white focus:border-cyan-400/60"
              />
            </label>
            <div className="mt-1.5 flex items-center justify-between text-[11px]">
              <span className={over ? "text-rose-300" : "text-zinc-500"}>
                {used} / {platform.limit} characters including the link
                {over ? ". Too long for this network" : ""}
              </span>
              {edited !== null && (
                <button type="button" onClick={() => setEdited(null)} className="cursor-pointer text-cyan-300 hover:underline">
                  Reset draft
                </button>
              )}
            </div>
          </>
        )}

        <p className="mt-3 flex items-center gap-2 truncate rounded-lg border border-white/10 bg-white/[0.03] px-3 py-2 font-mono text-[11px] text-zinc-400">
          <Link2 className="h-3.5 w-3.5 shrink-0" />
          <span className="truncate">{url}</span>
        </p>

        <div className="mt-5 grid gap-2 sm:grid-cols-2">
          <a
            href={platform.compose(caption, url, title)}
            target="_blank"
            rel="noopener noreferrer"
            className="cz-btn cz-btn-primary sm:col-span-2"
          >
            <ExternalLink className="h-4 w-4" />
            Open {platform.label} with this draft
          </a>
          <button type="button" onClick={() => copy("caption")} className="cz-btn cz-btn-ghost text-xs">
            {copied === "caption" ? <Check className="h-3.5 w-3.5" /> : <Copy className="h-3.5 w-3.5" />}
            {copied === "caption" ? "Copied" : "Copy caption + link"}
          </button>
          <button type="button" onClick={() => copy("link")} className="cz-btn cz-btn-ghost text-xs">
            {copied === "link" ? <Check className="h-3.5 w-3.5" /> : <Link2 className="h-3.5 w-3.5" />}
            {copied === "link" ? "Copied" : "Copy link only"}
          </button>
          {canNativeShare && (
            <button
              type="button"
              onClick={() => void navigator.share({ title, text: caption, url }).catch(() => undefined)}
              className="cz-btn cz-btn-ghost text-xs sm:col-span-2"
            >
              <Share2 className="h-3.5 w-3.5" />
              More apps…
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
