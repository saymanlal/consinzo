import type { Metadata } from "next";
import type { ReactNode } from "react";
import { pageMetadata } from "@/lib/site";

// The page itself is a client component, so its metadata lives in this layout.
export const metadata: Metadata = pageMetadata({
  title: "Competitions",
  description:
    "Timed smart-contract engineering competitions with team registration and standings scored by verified evaluation.",
  path: "/competitions",
});

export default function Layout({ children }: { children: ReactNode }) {
  return children;
}
