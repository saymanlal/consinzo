import type { Metadata } from "next";
import React from "react";
import { AppProviders } from "@/components/providers";
import { AppShell } from "@/components/app-shell";
import "./globals.css";

export const metadata: Metadata = {
  title: "CONSINZO — The Engineering Platform",
  description:
    "Build. Test. Break. Master. Multi-ecosystem blockchain smart-contract engineering, native compilation, automated testing, and security training.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <AppProviders>
          <AppShell>{children}</AppShell>
        </AppProviders>
      </body>
    </html>
  );
}
