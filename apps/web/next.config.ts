import path from "node:path";
import type { NextConfig } from "next";

const monorepoRoot = path.resolve(__dirname, "../..");

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
  outputFileTracingRoot: monorepoRoot,
  outputFileTracingIncludes: {
    "/challenges": ["../../content/challenges/**/*"],
    "/challenges/[slug]": ["../../content/challenges/**/*"],
    "/workspace/[slug]": ["../../content/challenges/**/*"],
    "/api/v1/**": ["../../content/challenges/**/*"],
  },
};

export default nextConfig;
