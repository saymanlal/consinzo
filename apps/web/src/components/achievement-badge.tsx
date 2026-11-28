import React from "react";
import {
  Braces,
  CheckCheck,
  Coins,
  Landmark,
  Lock,
  ShieldCheck,
  Star,
  Swords,
  Trophy,
  type LucideIcon,
} from "lucide-react";
import { getAchievementMeta, type AchievementIcon } from "@/lib/achievements";

const ICONS: Record<AchievementIcon, LucideIcon> = {
  check: CheckCheck,
  coins: Coins,
  shield: ShieldCheck,
  landmark: Landmark,
  swords: Swords,
  trophy: Trophy,
  braces: Braces,
  star: Star,
};

/** Hexagonal medallion for one achievement. Locked badges are greyed with a padlock. */
export function AchievementMedal({
  id,
  earned = true,
  size = "md",
  isNew = false,
}: {
  id: string;
  earned?: boolean;
  size?: "sm" | "md" | "lg";
  isNew?: boolean;
}) {
  const meta = getAchievementMeta(id);
  const Icon = earned ? ICONS[meta.icon] : Lock;
  const width = size === "lg" ? "w-28" : size === "sm" ? "w-12" : "w-20";
  return (
    <div
      className={`cz-medal ${width} ${earned ? "cz-medal-earned" : "cz-medal-locked"} ${
        isNew ? "cz-medal-new" : ""
      }`}
      style={{ "--m1": meta.colors[0], "--m2": meta.colors[1] } as React.CSSProperties}
      role="img"
      aria-label={`${meta.title}${earned ? "" : " (locked)"}`}
    >
      <div className="cz-medal-face" />
      <Icon className="cz-medal-icon" strokeWidth={1.75} aria-hidden />
    </div>
  );
}
