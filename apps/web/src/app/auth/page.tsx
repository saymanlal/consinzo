"use client";

import React, { Suspense, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useQueryClient } from "@tanstack/react-query";
import { ShieldCheck } from "lucide-react";
import { Button, Card, Input } from "@consinzo/ui";

function AuthFormInner() {
  const searchParams = useSearchParams();
  const initialMode = searchParams.get("mode") === "register" ? "register" : "login";
  const [mode, setMode] = useState<"login" | "register">(initialMode);
  const [email, setEmail] = useState("");
  const [username, setUsername] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const router = useRouter();
  const queryClient = useQueryClient();

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const endpoint = mode === "login" ? "/api/v1/auth/login" : "/api/v1/auth/register";
      const payload =
        mode === "login"
          ? { email, password }
          : { email, username, displayName, password };

      const res = await fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      const json = await res.json();
      if (!res.ok) {
        setError(json?.error?.message ?? "Authentication failed.");
        return;
      }
      await queryClient.invalidateQueries({ queryKey: ["auth-me"] });
      router.push("/dashboard");
      router.refresh();
    } catch {
      setError("Network error while authenticating.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="mx-auto max-w-md px-4 py-16">
      <Card className="p-6">
        <div className="flex items-center gap-2 text-xs font-mono uppercase tracking-wider text-zinc-500">
          <ShieldCheck className="h-4 w-4 text-blue-700" />
          CONSINZO Identity
        </div>
        <h1 className="mt-2 text-xl font-semibold text-zinc-950">
          {mode === "login" ? "Sign in to your engineering workspace" : "Create developer account"}
        </h1>
        <p className="mt-1 text-xs text-zinc-500">
          Sessions use HTTP-only signed cookies (or Supabase Auth when configured).
        </p>

        <div className="mt-5 grid grid-cols-2 rounded-md border border-zinc-200 bg-zinc-50 p-1 text-xs font-medium">
          <button
            type="button"
            onClick={() => setMode("login")}
            className={`rounded py-1.5 cursor-pointer ${
              mode === "login" ? "bg-white text-zinc-950 shadow-xs" : "text-zinc-500"
            }`}
          >
            Sign In
          </button>
          <button
            type="button"
            onClick={() => setMode("register")}
            className={`rounded py-1.5 cursor-pointer ${
              mode === "register" ? "bg-white text-zinc-950 shadow-xs" : "text-zinc-500"
            }`}
          >
            Register
          </button>
        </div>

        <form onSubmit={handleSubmit} className="mt-5 space-y-4">
          <div>
            <label className="block text-xs font-medium text-zinc-700 mb-1">Email</label>
            <Input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="engineer@domain.com"
            />
          </div>

          {mode === "register" && (
            <>
              <div>
                <label className="block text-xs font-medium text-zinc-700 mb-1">Username</label>
                <Input
                  type="text"
                  required
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  placeholder="sol_architect"
                />
              </div>
              <div>
                <label className="block text-xs font-medium text-zinc-700 mb-1">Display Name</label>
                <Input
                  type="text"
                  required
                  value={displayName}
                  onChange={(e) => setDisplayName(e.target.value)}
                  placeholder="Alex Rivera"
                />
              </div>
            </>
          )}

          <div>
            <label className="block text-xs font-medium text-zinc-700 mb-1">Password</label>
            <Input
              type="password"
              required
              minLength={8}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Minimum 8 characters"
            />
          </div>

          {error && (
            <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-800">
              {error}
            </div>
          )}

          <Button type="submit" disabled={loading} className="w-full">
            {loading
              ? "Authenticating..."
              : mode === "login"
                ? "Sign In"
                : "Create Developer Account"}
          </Button>
        </form>
      </Card>
    </div>
  );
}

export default function AuthPage() {
  return (
    <Suspense fallback={<div className="p-12 text-center text-xs text-zinc-500">Loading...</div>}>
      <AuthFormInner />
    </Suspense>
  );
}
