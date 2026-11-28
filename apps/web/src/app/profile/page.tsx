"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { ExternalLink } from "lucide-react";
import { Button, Card, Input, Textarea } from "@consinzo/ui";
import { WalletCard } from "@/components/wallet-card";

export default function ProfilePage() {
  const queryClient = useQueryClient();
  const { data } = useQuery({
    queryKey: ["my-profile"],
    queryFn: async () => (await fetch("/api/v1/profiles")).json(),
  });

  const [displayName, setDisplayName] = useState("");
  const [bio, setBio] = useState("");
  const [githubUrl, setGithubUrl] = useState("");
  const [websiteUrl, setWebsiteUrl] = useState("");
  const [status, setStatus] = useState<string | null>(null);

  useEffect(() => {
    if (data?.profile) {
      setDisplayName(data.profile.displayName ?? "");
      setBio(data.profile.bio ?? "");
      setGithubUrl(data.profile.githubUrl ?? "");
      setWebsiteUrl(data.profile.websiteUrl ?? "");
    }
  }, [data]);

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setStatus(null);
    const res = await fetch("/api/v1/profiles", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ displayName, bio, githubUrl, websiteUrl }),
    });
    if (res.ok) {
      setStatus("Profile updated.");
      await queryClient.invalidateQueries({ queryKey: ["auth-me"] });
    } else {
      setStatus("Failed to update profile.");
    }
  }

  if (!data?.profile) {
    return (
      <div className="mx-auto max-w-xl px-4 py-16 text-center space-y-4">
        <p className="text-xs text-zinc-500">
          Sign in to manage your developer profile and portfolio links.
        </p>
        <Link
          href="/auth"
          className="inline-flex rounded-md bg-slate-900 px-4 py-2 text-xs font-medium text-white"
        >
          Sign In / Create Account
        </Link>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-2xl px-4 py-8">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold text-zinc-950">Developer Profile & Portfolio</h1>
          <p className="mt-1 text-xs text-zinc-500">
            Username <span className="font-mono">@{data.profile.username}</span> · Verified Points:{" "}
            <span className="font-mono font-semibold">{data.profile.totalPoints}</span>
          </p>
        </div>
        <Link
          href={`/u/${data.profile.username}`}
          className="inline-flex items-center gap-1.5 rounded-md border border-zinc-300 bg-white px-3 py-1.5 text-xs font-medium text-zinc-900 hover:bg-zinc-50"
        >
          View Public Portfolio
          <ExternalLink className="h-3.5 w-3.5" />
        </Link>
      </div>

      <Card className="mt-6 p-6">
        <form onSubmit={handleSave} className="space-y-4 text-xs">
          <div>
            <label className="block font-medium text-zinc-700 mb-1">Display Name</label>
            <Input
              required
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value)}
            />
          </div>
          <div>
            <label className="block font-medium text-zinc-700 mb-1">Technical Bio</label>
            <Textarea
              rows={3}
              value={bio}
              onChange={(e) => setBio(e.target.value)}
              placeholder="Smart contract security researcher & DeFi protocol engineer..."
            />
          </div>
          <div>
            <label className="block font-medium text-zinc-700 mb-1">GitHub URL</label>
            <Input
              type="url"
              value={githubUrl}
              onChange={(e) => setGithubUrl(e.target.value)}
              placeholder="https://github.com/username"
            />
          </div>
          <div>
            <label className="block font-medium text-zinc-700 mb-1">Website / Portfolio URL</label>
            <Input
              type="url"
              value={websiteUrl}
              onChange={(e) => setWebsiteUrl(e.target.value)}
              placeholder="https://example.dev"
            />
          </div>
          {status && <div className="text-emerald-700 font-medium">{status}</div>}
          <Button type="submit">Save Profile</Button>
        </form>
      </Card>

      {data.profile.walletAddress && (
        <div className="mt-6">
          <WalletCard address={data.profile.walletAddress} />
        </div>
      )}
    </div>
  );
}
