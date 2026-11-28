import type { Metadata } from "next";
import type { ReactNode } from "react";
import { pageMetadata } from "@/lib/site";

// The page itself is a client component, so its metadata lives in this layout.
export const metadata: Metadata = pageMetadata({
  title: "Security Arena",
  description:
    "Exploit-and-patch security missions for smart contracts: reentrancy, signature replay, oracle manipulation, upgrade authorization and more, verified by hidden tests.",
  path: "/security",
});

export default function Layout({ children }: { children: ReactNode }) {
  return children;
}
