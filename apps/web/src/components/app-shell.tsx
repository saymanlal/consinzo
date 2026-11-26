"use client";

import React, { useState } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import {
  BookOpen,
  Code2,
  Cpu,
  GraduationCap,
  Layers,
  LayoutDashboard,
  LogOut,
  Menu,
  Shield,
  Terminal,
  Trophy,
  User,
  X,
} from "lucide-react";

interface MeResponse {
  user: {
    id: string;
    email: string;
    username: string;
    displayName: string;
    roles: string[];
    totalPoints: number;
    challengesCompleted: number;
  } | null;
}

const NAV_ITEMS = [
  { href: "/", label: "Overview", icon: Terminal },
  { href: "/challenges", label: "Code", icon: Code2 },
  { href: "/security", label: "Security", icon: Shield },
  { href: "/protocols", label: "Protocols", icon: Layers },
  { href: "/ecosystems", label: "Ecosystems", icon: Cpu },
  { href: "/knowledge", label: "Knowledge", icon: BookOpen },
  { href: "/competitions", label: "Competitions", icon: Trophy },
  { href: "/academy", label: "Academy", icon: GraduationCap },
];

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const queryClient = useQueryClient();
  const [mobileOpen, setMobileOpen] = useState(false);

  const isWorkspaceRoute = pathname?.startsWith("/workspace/");

  const { data } = useQuery<MeResponse>({
    queryKey: ["auth-me"],
    queryFn: async () => {
      const res = await fetch("/api/v1/auth/me");
      if (!res.ok) return { user: null };
      return res.json();
    },
  });

  const user = data?.user ?? null;
  const isAdmin = Boolean(
    user?.roles.some((r) =>
      ["super_admin", "platform_admin", "challenge_manager", "security_reviewer"].includes(r)
    )
  );

  async function handleLogout() {
    await fetch("/api/v1/auth/logout", { method: "POST" });
    await queryClient.invalidateQueries({ queryKey: ["auth-me"] });
    router.refresh();
  }

  return (
    <div className="min-h-screen flex flex-col bg-[#FAFAFA] text-zinc-950">
      <header className="sticky top-0 z-40 h-14 border-b border-zinc-200 bg-white/95 backdrop-blur">
        <div className="mx-auto flex h-full max-w-[1440px] items-center justify-between px-4 lg:px-6">
          <div className="flex items-center gap-6">
            <Link href="/" className="flex items-center gap-2.5 font-semibold tracking-tight">
              <span className="flex h-7 w-7 items-center justify-center rounded border border-slate-900 bg-slate-900 text-xs font-mono text-white">
                CZ
              </span>
              <span className="text-sm tracking-wider uppercase text-zinc-950">CONSINZO</span>
            </Link>

            <nav className="hidden lg:flex items-center gap-1">
              {NAV_ITEMS.map((item) => {
                const Icon = item.icon;
                const active =
                  item.href === "/" ? pathname === "/" : pathname?.startsWith(item.href);
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className={`flex items-center gap-1.5 rounded-md px-2.5 py-1.5 text-xs font-medium transition-colors ${
                      active
                        ? "bg-zinc-900 text-white"
                        : "text-zinc-600 hover:bg-zinc-100 hover:text-zinc-950"
                    }`}
                  >
                    <Icon className="h-3.5 w-3.5" />
                    {item.label}
                  </Link>
                );
              })}
            </nav>
          </div>

          <div className="flex items-center gap-2">
            {user ? (
              <div className="hidden sm:flex items-center gap-2">
                <Link
                  href="/dashboard"
                  className="inline-flex items-center gap-1.5 rounded-md border border-zinc-200 bg-zinc-50 px-2.5 py-1.5 text-xs font-medium text-zinc-800 hover:bg-zinc-100"
                >
                  <LayoutDashboard className="h-3.5 w-3.5" />
                  Dashboard
                </Link>
                <Link
                  href="/profile"
                  className="inline-flex items-center gap-1.5 rounded-md border border-zinc-200 bg-white px-2.5 py-1.5 text-xs font-medium text-zinc-800 hover:bg-zinc-50"
                >
                  <User className="h-3.5 w-3.5" />
                  <span className="font-mono">{user.username}</span>
                  <span className="text-zinc-400">|</span>
                  <span>{user.totalPoints} pts</span>
                </Link>
                {isAdmin && (
                  <Link
                    href="/admin"
                    className="inline-flex items-center rounded-md border border-blue-200 bg-blue-50 px-2.5 py-1.5 text-xs font-medium text-blue-800 hover:bg-blue-100"
                  >
                    Admin
                  </Link>
                )}
                <button
                  type="button"
                  onClick={handleLogout}
                  title="Sign out"
                  className="inline-flex h-8 w-8 items-center justify-center rounded-md border border-zinc-200 text-zinc-600 hover:bg-zinc-100 hover:text-zinc-950 cursor-pointer"
                >
                  <LogOut className="h-3.5 w-3.5" />
                </button>
              </div>
            ) : (
              <div className="hidden sm:flex items-center gap-2">
                <Link
                  href="/auth"
                  className="rounded-md border border-zinc-300 bg-white px-3 py-1.5 text-xs font-medium text-zinc-800 hover:bg-zinc-50"
                >
                  Sign In
                </Link>
                <Link
                  href="/auth?mode=register"
                  className="rounded-md bg-slate-900 px-3 py-1.5 text-xs font-medium text-white hover:bg-slate-800"
                >
                  Create Account
                </Link>
              </div>
            )}

            <button
              type="button"
              onClick={() => setMobileOpen((o) => !o)}
              className="lg:hidden inline-flex h-8 w-8 items-center justify-center rounded-md border border-zinc-200 text-zinc-700"
              aria-label="Toggle navigation"
            >
              {mobileOpen ? <X className="h-4 w-4" /> : <Menu className="h-4 w-4" />}
            </button>
          </div>
        </div>

        {mobileOpen && (
          <div className="lg:hidden border-b border-zinc-200 bg-white px-4 py-3 space-y-1">
            {NAV_ITEMS.map((item) => {
              const Icon = item.icon;
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  onClick={() => setMobileOpen(false)}
                  className="flex items-center gap-2 rounded-md px-3 py-2 text-sm text-zinc-700 hover:bg-zinc-100"
                >
                  <Icon className="h-4 w-4" />
                  {item.label}
                </Link>
              );
            })}
            <div className="pt-2 border-t border-zinc-100 flex gap-2">
              {user ? (
                <Link
                  href="/dashboard"
                  onClick={() => setMobileOpen(false)}
                  className="w-full rounded-md bg-slate-900 px-3 py-2 text-center text-xs font-medium text-white"
                >
                  Dashboard ({user.username})
                </Link>
              ) : (
                <Link
                  href="/auth"
                  onClick={() => setMobileOpen(false)}
                  className="w-full rounded-md bg-slate-900 px-3 py-2 text-center text-xs font-medium text-white"
                >
                  Sign In / Register
                </Link>
              )}
            </div>
          </div>
        )}
      </header>

      <main className="flex-1">{children}</main>

      {!isWorkspaceRoute && (
        <footer className="border-t border-zinc-200 bg-white">
          <div className="mx-auto flex max-w-[1440px] flex-col gap-4 px-4 py-8 text-xs text-zinc-500 sm:flex-row sm:items-center sm:justify-between lg:px-6">
            <div>
              <span className="font-semibold text-zinc-900">CONSINZO</span> — The Engineering
              Platform. Proprietary Software. All Rights Reserved.
            </div>
            <div className="flex flex-wrap items-center gap-4">
              <Link href="/docs" className="hover:text-zinc-900">
                Documentation
              </Link>
              <Link href="/about" className="hover:text-zinc-900">
                About
              </Link>
              <Link href="/legal/security" className="hover:text-zinc-900">
                Security Policy
              </Link>
              <Link href="/legal/privacy" className="hover:text-zinc-900">
                Privacy Policy
              </Link>
              <Link href="/legal/terms" className="hover:text-zinc-900">
                Terms of Service
              </Link>
            </div>
          </div>
        </footer>
      )}
    </div>
  );
}
