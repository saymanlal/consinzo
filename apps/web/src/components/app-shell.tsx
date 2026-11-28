"use client";

import React, { useEffect, useState } from "react";
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
import { BrandLogo } from "@/components/brand-logo";

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

const FOOTER_GROUPS = [
  {
    title: "Platform",
    links: [
      { href: "/challenges", label: "Challenge Codex" },
      { href: "/security", label: "Security Arena" },
      { href: "/protocols", label: "Protocol Lab" },
      { href: "/competitions", label: "Competitions" },
    ],
  },
  {
    title: "Learn",
    links: [
      { href: "/academy", label: "Academy" },
      { href: "/knowledge", label: "Knowledge Hub" },
      { href: "/ecosystems", label: "Ecosystem Hub" },
      { href: "/docs", label: "Documentation" },
    ],
  },
  {
    title: "Company",
    links: [
      { href: "/about", label: "About" },
      { href: "/contact", label: "Contact" },
      { href: "/legal/security", label: "Security Policy" },
      { href: "/legal/privacy", label: "Privacy Policy" },
      { href: "/legal/terms", label: "Terms of Service" },
    ],
  },
];

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const queryClient = useQueryClient();
  const [mobileOpen, setMobileOpen] = useState(false);

  const isWorkspaceRoute = pathname?.startsWith("/workspace/");

  // Close the mobile drawer on navigation.
  useEffect(() => {
    setMobileOpen(false);
  }, [pathname]);

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
    <div className="flex min-h-screen flex-col bg-[#FAFAFA] text-zinc-950">
      <a
        href="#main"
        className="sr-only focus:not-sr-only focus:fixed focus:left-3 focus:top-3 focus:z-50 focus:rounded-md focus:bg-white focus:px-3 focus:py-2 focus:text-xs focus:font-medium focus:text-zinc-950"
      >
        Skip to content
      </a>
      <header className="sticky top-0 z-40 border-b border-white/10 bg-[#09090B]/85 text-white backdrop-blur-xl">
        <div className="mx-auto flex h-14 max-w-[1440px] items-center justify-between gap-3 px-4 lg:px-6">
          <div className="flex min-w-0 items-center gap-5">
            <Link href="/" aria-label="CONSINZO home" className="cz-focus flex items-center rounded text-white">
              <BrandLogo />
            </Link>

            <nav aria-label="Primary" className="hidden items-center gap-0.5 xl:flex">
              {NAV_ITEMS.map((item) => {
                const Icon = item.icon;
                const active =
                  item.href === "/" ? pathname === "/" : pathname?.startsWith(item.href);
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    aria-current={active ? "page" : undefined}
                    className={`cz-focus flex items-center gap-1.5 rounded-md px-2.5 py-1.5 text-xs font-medium transition-colors ${
                      active
                        ? "bg-white text-zinc-950"
                        : "text-zinc-400 hover:bg-white/10 hover:text-white"
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
              <div className="hidden items-center gap-2 sm:flex">
                <Link
                  href="/dashboard"
                  className="cz-focus inline-flex items-center gap-1.5 rounded-md border border-white/15 bg-white/5 px-2.5 py-1.5 text-xs font-medium text-zinc-100 hover:bg-white/10"
                >
                  <LayoutDashboard className="h-3.5 w-3.5" />
                  Dashboard
                </Link>
                <Link
                  href="/profile"
                  className="cz-focus inline-flex max-w-[15rem] items-center gap-1.5 rounded-md border border-white/15 bg-white/5 px-2.5 py-1.5 text-xs font-medium text-zinc-100 hover:bg-white/10"
                >
                  <User className="h-3.5 w-3.5 shrink-0" />
                  <span className="truncate font-mono">{user.username}</span>
                  <span className="text-zinc-600">|</span>
                  <span className="shrink-0">{user.totalPoints} pts</span>
                </Link>
                {isAdmin && (
                  <Link
                    href="/admin"
                    className="cz-focus inline-flex items-center rounded-md border border-cyan-400/30 bg-cyan-400/10 px-2.5 py-1.5 text-xs font-medium text-cyan-200 hover:bg-cyan-400/20"
                  >
                    Admin
                  </Link>
                )}
                <button
                  type="button"
                  onClick={handleLogout}
                  title="Sign out"
                  aria-label="Sign out"
                  className="cz-focus inline-flex h-8 w-8 cursor-pointer items-center justify-center rounded-md border border-white/15 text-zinc-300 hover:bg-white/10 hover:text-white"
                >
                  <LogOut className="h-3.5 w-3.5" />
                </button>
              </div>
            ) : (
              <div className="hidden items-center gap-2 sm:flex">
                <Link
                  href="/auth"
                  className="cz-focus rounded-md border border-white/15 px-3 py-1.5 text-xs font-medium text-zinc-100 hover:bg-white/10"
                >
                  Sign In
                </Link>
                <Link
                  href="/auth?mode=register"
                  className="cz-focus rounded-md bg-white px-3 py-1.5 text-xs font-semibold text-zinc-950 hover:bg-zinc-200"
                >
                  Create Account
                </Link>
              </div>
            )}

            <button
              type="button"
              onClick={() => setMobileOpen((o) => !o)}
              className="cz-focus inline-flex h-9 w-9 items-center justify-center rounded-md border border-white/15 text-zinc-200 xl:hidden"
              aria-label="Toggle navigation"
              aria-expanded={mobileOpen}
              aria-controls="mobile-nav"
            >
              {mobileOpen ? <X className="h-4 w-4" /> : <Menu className="h-4 w-4" />}
            </button>
          </div>
        </div>

        {mobileOpen && (
          <div
            id="mobile-nav"
            className="max-h-[calc(100dvh-3.5rem)] overflow-y-auto border-t border-white/10 bg-[#09090B] px-4 py-3 xl:hidden"
          >
            <nav aria-label="Mobile" className="grid grid-cols-2 gap-1">
              {NAV_ITEMS.map((item) => {
                const Icon = item.icon;
                const active =
                  item.href === "/" ? pathname === "/" : pathname?.startsWith(item.href);
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className={`flex items-center gap-2 rounded-md px-3 py-2.5 text-sm ${
                      active ? "bg-white text-zinc-950" : "text-zinc-300 hover:bg-white/10"
                    }`}
                  >
                    <Icon className="h-4 w-4" />
                    {item.label}
                  </Link>
                );
              })}
            </nav>
            <div className="mt-3 flex flex-wrap gap-2 border-t border-white/10 pt-3">
              {user ? (
                <>
                  <Link
                    href="/dashboard"
                    className="flex-1 rounded-md bg-white px-3 py-2.5 text-center text-xs font-semibold text-zinc-950"
                  >
                    Dashboard
                  </Link>
                  <Link
                    href="/profile"
                    className="flex-1 truncate rounded-md border border-white/15 px-3 py-2.5 text-center text-xs font-medium text-white"
                  >
                    {user.username}
                  </Link>
                  <button
                    type="button"
                    onClick={handleLogout}
                    className="flex-1 cursor-pointer rounded-md border border-white/15 px-3 py-2.5 text-center text-xs font-medium text-white"
                  >
                    Sign out
                  </button>
                </>
              ) : (
                <>
                  <Link
                    href="/auth"
                    className="flex-1 rounded-md border border-white/15 px-3 py-2.5 text-center text-xs font-medium text-white"
                  >
                    Sign In
                  </Link>
                  <Link
                    href="/auth?mode=register"
                    className="flex-1 rounded-md bg-white px-3 py-2.5 text-center text-xs font-semibold text-zinc-950"
                  >
                    Create Account
                  </Link>
                </>
              )}
            </div>
          </div>
        )}
      </header>

      <main id="main" className="flex-1">
        {children}
      </main>

      {!isWorkspaceRoute && (
        <footer className="border-t border-white/10 bg-[#09090B] text-zinc-400">
          <div className="mx-auto grid max-w-[1200px] gap-10 px-5 py-12 sm:px-6 md:grid-cols-[1.4fr_repeat(3,1fr)]">
            <div>
              <BrandLogo className="text-white" markClassName="h-8 w-8" wordmarkClassName="text-base" />
              <p className="mt-4 max-w-xs text-sm leading-relaxed">
                The Engineering Platform. Build. Test. Break. Master.
              </p>
            </div>
            {FOOTER_GROUPS.map((group) => (
              <nav key={group.title} aria-label={group.title}>
                <h2 className="font-mono text-[11px] uppercase tracking-[0.18em] text-zinc-500">
                  {group.title}
                </h2>
                <ul className="mt-4 space-y-2.5 text-sm">
                  {group.links.map((l) => (
                    <li key={l.href}>
                      <Link href={l.href} className="cz-focus rounded hover:text-white">
                        {l.label}
                      </Link>
                    </li>
                  ))}
                </ul>
              </nav>
            ))}
          </div>
          <div className="border-t border-white/10">
            <div className="mx-auto max-w-[1200px] px-5 py-5 text-xs text-zinc-500 sm:px-6">
              © {new Date().getFullYear()} CONSINZO. Proprietary software. All rights reserved.
            </div>
          </div>
        </footer>
      )}
    </div>
  );
}
