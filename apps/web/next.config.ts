import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: [
    "@consinzo/shared",
    "@consinzo/ecosystem-registry",
    "@consinzo/challenge-spec",
    "@consinzo/scoring",
    "@consinzo/execution-sdk",
    "@consinzo/validators",
    "@consinzo/ui",
    "@consinzo/editor",
    "@consinzo/runner-common",
    "@consinzo/runner-evm",
  ],
  serverExternalPackages: ["solc"],
  poweredByHeader: false,
};

export default nextConfig;
