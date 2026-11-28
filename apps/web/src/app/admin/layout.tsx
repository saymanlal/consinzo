import type { Metadata } from "next";
import type { ReactNode } from "react";
import { pageMetadata } from "@/lib/site";

// The page itself is a client component, so its metadata lives in this layout.
export const metadata: Metadata = pageMetadata({
  title: "Admin",
  description:
    "CONSINZO administration.",
  path: "/admin",
  noIndex: true,
});

export default function Layout({ children }: { children: ReactNode }) {
  return children;
}
