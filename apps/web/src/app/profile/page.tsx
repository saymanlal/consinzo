"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { ExternalLink, Fingerprint, Mail, Smartphone, Wallet } from "lucide-react";
import { Button, Card, Input, Textarea } from "@consinzo/ui";
import { Avatar } from "@/components/avatar";
import { BadgeShowcase } from "@/components/badge-showcase";
import { Container, DarkBand } from "@/components/marketing/blocks";
import { WalletCard } from "@/components/wallet-card";

interface MeData {
  user: {
    username: string;
    displayName: string;
    email: string;
    phone: string | null;
    walletAddress: string | null;
    authProvider: string;
    totalPoints: number;
    challengesCompleted: number;
    securityMissionsCompleted: number;
    bio: string;
    githubUrl: string;
    websiteUrl: string;
  } | null;
  achievements?: Array<{ achievementId: string; awardedAt: string }>;
}

const PROVIDER_LABEL: Record<string, string> = {
  password: "Email and password",
  wallet: "Wallet signature",
  "email-code": "Email code",
  email: "Email",
  phone: "Phone code",
  google: "Google",
  github: "GitHub",
};

export default function ProfilePage() {
  const queryClient = useQueryClient();
  const { data, isLoading } = useQuery<MeData>({
    queryKey: ["auth-me"],
    queryFn: async () => {
      const res = await fetch("/api/v1/auth/me");
      return res.ok ? res.json() : { user: null };
    },
  });
  const user = data?.user ?? null;

  const [displayName, setDisplayName] = useState("");
  const [bio, setBio] = useState("");
  const [githubUrl, setGithubUrl] = useState("");
  const [websiteUrl, setWebsiteUrl] = useState("");
  const [status, setStatus] = useState<{ ok: boolean; text: string } | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (user) {
      setDisplayName(user.displayName ?? "");
      setBio(user.bio ?? "");
      setGithubUrl(user.githubUrl ?? "");
      setWebsiteUrl(user.websiteUrl ?? "");
    }
    // Only re-seed the form when a different account loads.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.username]);

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setStatus(null);
    setSaving(true);
    try {
      const res = await fetch("/api/v1/profiles", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ displayName, bio, githubUrl, websiteUrl }),
      });
      if (res.ok) {
        setStatus({ ok: true, text: "Profile saved." });
        await queryClient.invalidateQueries({ queryKey: ["auth-me"] });
      } else {
        setStatus({ ok: false, text: "Could not save. Check that links start with https://." });
      }
    } catch {
      setStatus({ ok: false, text: "Network error. Try again." });
    } finally {
      setSaving(false);
    }
  }

  if (isLoading) {
    return <div className="py-24 text-center text-sm text-zinc-500">Loading your profile…</div>;
  }

  if (!user) {
    return (
      <DarkBand className="min-h-[60vh]">
        <Container className="py-24 text-center">
          <h1 className="text-3xl font-semibold text-white">Your profile lives here</h1>
          <p className="mx-auto mt-3 max-w-md text-sm text-zinc-400">
            Sign in to see your badges, share them, and manage your portfolio links.
          </p>
          <Link href="/auth?next=/profile" className="cz-btn cz-btn-primary mt-8">
            Sign in or create an account
          </Link>
        </Container>
      </DarkBand>
    );
  }

  const identities = [
    user.email ? { icon: Mail, label: "Email", value: user.email } : null,
    user.phone ? { icon: Smartphone, label: "Phone", value: user.phone } : null,
    user.walletAddress
      ? {
          icon: Wallet,
          label: "Wallet",
          value: `${user.walletAddress.slice(0, 6)}…${user.walletAddress.slice(-4)}`,
        }
      : null,
  ].filter((x): x is NonNullable<typeof x> => Boolean(x));

  return (
    <>
      <DarkBand>
        <Container className="py-10 sm:py-14">
          <header className="flex flex-wrap items-center gap-5">
            <Avatar username={user.username} displayName={user.displayName} />
            <div className="min-w-0 flex-1">
              <h1 className="break-words text-2xl font-semibold tracking-tight text-white sm:text-3xl">
                {user.displayName}
              </h1>
              <p className="mt-1 font-mono text-xs text-zinc-500">@{user.username}</p>
            </div>
            <Link href={`/u/${user.username}`} className="cz-btn cz-btn-ghost px-3 py-2 text-xs">
              View public portfolio
              <ExternalLink className="h-3.5 w-3.5" />
            </Link>
          </header>

          <dl className="mt-8 grid grid-cols-2 gap-3 sm:grid-cols-4">
            {[
              { label: "Verified score", value: user.totalPoints.toLocaleString("en-US") },
              { label: "Challenges passed", value: user.challengesCompleted },
              { label: "Security missions", value: user.securityMissionsCompleted },
              { label: "Badges", value: data?.achievements?.length ?? 0 },
            ].map((s) => (
              <div key={s.label} className="cz-card p-4">
                <dt className="text-xs text-zinc-500">{s.label}</dt>
                <dd className="mt-1 font-mono text-2xl font-semibold text-white">{s.value}</dd>
              </div>
            ))}
          </dl>

          <div className="mt-10">
            <BadgeShowcase
              profile={{
                username: user.username,
                displayName: user.displayName,
                totalPoints: user.totalPoints,
                challengesCompleted: user.challengesCompleted,
                securityMissionsCompleted: user.securityMissionsCompleted,
              }}
              earned={data?.achievements ?? []}
            />
          </div>
        </Container>
      </DarkBand>

      <div className="mx-auto grid max-w-[1200px] gap-6 px-5 py-10 sm:px-6 lg:grid-cols-[1.2fr_0.8fr]">
        <Card className="p-6">
          <h2 className="text-sm font-semibold text-zinc-950">Public details</h2>
          <form onSubmit={handleSave} className="mt-4 space-y-4 text-xs">
            <label className="block font-medium text-zinc-700">
              Display name
              <Input required minLength={2} maxLength={60} value={displayName} onChange={(e) => setDisplayName(e.target.value)} className="mt-1" />
            </label>
            <label className="block font-medium text-zinc-700">
              Bio
              <Textarea rows={3} maxLength={400} value={bio} onChange={(e) => setBio(e.target.value)} placeholder="Smart contract security researcher and DeFi protocol engineer…" className="mt-1" />
            </label>
            <div className="grid gap-4 sm:grid-cols-2">
              <label className="block font-medium text-zinc-700">
                GitHub URL
                <Input type="url" value={githubUrl} onChange={(e) => setGithubUrl(e.target.value)} placeholder="https://github.com/username" className="mt-1" />
              </label>
              <label className="block font-medium text-zinc-700">
                Website
                <Input type="url" value={websiteUrl} onChange={(e) => setWebsiteUrl(e.target.value)} placeholder="https://example.dev" className="mt-1" />
              </label>
            </div>
            <div className="flex flex-wrap items-center gap-3">
              <Button type="submit" disabled={saving}>
                {saving ? "Saving…" : "Save profile"}
              </Button>
              {status && (
                <span role="status" className={`font-medium ${status.ok ? "text-emerald-700" : "text-red-700"}`}>
                  {status.text}
                </span>
              )}
            </div>
          </form>
        </Card>

        <div className="space-y-6">
          <Card className="p-6">
            <h2 className="flex items-center gap-2 text-sm font-semibold text-zinc-950">
              <Fingerprint className="h-4 w-4 text-blue-700" />
              Sign-in
            </h2>
            <p className="mt-1 text-xs text-zinc-500">
              Account created with: {PROVIDER_LABEL[user.authProvider] ?? user.authProvider}. These
              details are private and never shown on your public portfolio.
            </p>
            <ul className="mt-3 space-y-2 text-xs">
              {identities.map((i) => (
                <li key={i.label} className="flex items-center gap-2 rounded-md border border-zinc-200 bg-zinc-50 px-3 py-2">
                  <i.icon className="h-3.5 w-3.5 shrink-0 text-zinc-500" />
                  <span className="text-zinc-500">{i.label}</span>
                  <span className="ml-auto truncate font-mono text-zinc-900">{i.value}</span>
                </li>
              ))}
            </ul>
          </Card>
          {user.walletAddress && <WalletCard address={user.walletAddress} />}
        </div>
      </div>
    </>
  );
}
