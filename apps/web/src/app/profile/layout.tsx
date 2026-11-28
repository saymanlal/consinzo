import type { Metadata } from "next";
import type { ReactNode } from "react";
import { pageMetadata } from "@/lib/site";

// The page itself is a client component, so its metadata lives in this layout.
export const metadata: Metadata = pageMetadata({
  title: "Your profile",
  description:
    "Manage your CONSINZO profile, badges and sign-in details.",
  path: "/profile",
  noIndex: true,
});

export default function Layout({ children }: { children: ReactNode }) {
  return children;
}
