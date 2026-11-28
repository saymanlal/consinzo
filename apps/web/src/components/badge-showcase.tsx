"use client";

import React, { useState } from "react";
import { Share2 } from "lucide-react";
import { AchievementMedal } from "@/components/achievement-badge";
import { ShareDialog } from "@/components/share-dialog";
import { ACHIEVEMENT_ORDER, getAchievementMeta } from "@/lib/achievements";
import type { ShareSubject } from "@/lib/share";

export interface ShowcaseProfile {
  username: string;
  displayName: string;
  totalPoints: number;
  challengesCompleted: number;
  securityMissionsCompleted: number;
}

/**
 * Badge wall: every achievement as a medallion, earned ones in colour with their date,
 * the rest locked with what it takes to earn them. Earned badges and the profile itself
 * can be shared with an auto-drafted caption.
 */
export function BadgeShowcase({
  profile,
  earned,
  highlightId,
}: {
  profile: ShowcaseProfile;
  earned: Array<{ achievementId: string; awardedAt: string }>;
  highlightId?: string;
}) {
  const [sharing, setSharing] = useState<{ badgeId?: string } | null>(null);
  const earnedMap = new Map(earned.map((a) => [a.achievementId, a.awardedAt]));
  const ids = [...new Set([...ACHIEVEMENT_ORDER, ...earnedMap.keys()])].sort(
    (a, b) => Number(earnedMap.has(b)) - Number(earnedMap.has(a))
  );

  const subject = (badgeId?: string): ShareSubject => {
    const meta = badgeId ? getAchievementMeta(badgeId) : null;
    return {
      ...profile,
      badgeCount: earnedMap.size,
      badge: meta ? { title: meta.title, feat: meta.feat, track: meta.track } : undefined,
    };
  };

  return (
    <section aria-labelledby="badges-heading">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 id="badges-heading" className="text-lg font-semibold text-white">
            Badges
          </h2>
          <p className="mt-0.5 text-xs text-zinc-500">
            {earnedMap.size} of {ids.length} earned. Each one is awarded by the server after
            verified evaluation.
          </p>
        </div>
        <button type="button" onClick={() => setSharing({})} className="cz-btn cz-btn-ghost px-3 py-2 text-xs">
          <Share2 className="h-3.5 w-3.5" />
          Share profile
        </button>
      </div>

      <ul className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
        {ids.map((id) => {
          const meta = getAchievementMeta(id);
          const awardedAt = earnedMap.get(id);
          const isEarned = Boolean(awardedAt);
          const highlighted = highlightId === id && isEarned;
          return (
            <li
              key={id}
              className={`cz-card flex flex-col items-center p-4 text-center ${
                isEarned ? "cz-card-hover" : ""
              } ${highlighted ? "ring-2 ring-cyan-400/70" : ""}`}
            >
              <AchievementMedal id={id} earned={isEarned} isNew={highlighted} />
              <p className="mt-3 font-mono text-[10px] uppercase tracking-[0.16em] text-zinc-500">
                {meta.track}
              </p>
              <h3 className={`mt-1 text-sm font-semibold ${isEarned ? "text-white" : "text-zinc-500"}`}>
                {meta.title}
              </h3>
              <p className="mt-1 text-[11px] leading-relaxed text-zinc-500">{meta.description}</p>
              {isEarned ? (
                <>
                  <p className="mt-2 text-[11px] text-emerald-300">
                    Earned{" "}
                    <time dateTime={awardedAt}>
                      {new Date(awardedAt!).toLocaleDateString("en-US", {
                        year: "numeric",
                        month: "short",
                        day: "numeric",
                        timeZone: "UTC",
                      })}
                    </time>
                  </p>
                  <button
                    type="button"
                    onClick={() => setSharing({ badgeId: id })}
                    className="cz-focus mt-3 inline-flex cursor-pointer items-center gap-1.5 rounded-full border border-white/15 px-3 py-1 text-[11px] font-medium text-zinc-200 hover:border-cyan-400/60 hover:text-white"
                  >
                    <Share2 className="h-3 w-3" />
                    Share
                  </button>
                </>
              ) : (
                <p className="mt-2 text-[11px] text-zinc-600">Locked</p>
              )}
            </li>
          );
        })}
      </ul>

      {sharing && (
        <ShareDialog
          subject={subject(sharing.badgeId)}
          badgeId={sharing.badgeId}
          onClose={() => setSharing(null)}
        />
      )}
    </section>
  );
}
