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
    "@consinzo/runner-near",
  ],
  serverExternalPackages: ["solc"],
  poweredByHeader: false,
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          // The site asks users to sign wallet messages: it must never be framed by another origin.
          { key: "X-Frame-Options", value: "SAMEORIGIN" },
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains" },
          {
            key: "Permissions-Policy",
            value: "camera=(), microphone=(), geolocation=(), payment=(), usb=()",
          },
        ],
      },
    ];
  },
  outputFileTracingRoot: monorepoRoot,
  outputFileTracingIncludes: {
    "/challenges": ["../../content/challenges/**/*"],
    "/challenges/[slug]": ["../../content/challenges/**/*"],
    "/workspace/[slug]": ["../../content/challenges/**/*"],
    "/api/v1/**": ["../../content/challenges/**/*"],
  },
};

export default nextConfig;
