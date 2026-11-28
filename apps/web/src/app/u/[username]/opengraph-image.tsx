import { ImageResponse } from "next/og";
import { BRAND_MARK_PATH } from "@/components/brand-mark-path";
import { getPublicDeveloperPortfolio } from "@/lib/data-adapter";

export const alt = "CONSINZO developer profile";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";
export const dynamic = "force-dynamic";

/** Link-preview card for a public profile: name, handle and verified numbers. */
export default async function Image({ params }: { params: Promise<{ username: string }> }) {
  const { username } = await params;
  const p = await getPublicDeveloperPortfolio(username);
  const stats = p
    ? [
        { label: "VERIFIED POINTS", value: p.totalPoints.toLocaleString("en-US") },
        { label: "CHALLENGES", value: String(p.challengesCompleted) },
        { label: "SECURITY MISSIONS", value: String(p.securityMissionsCompleted) },
        { label: "BADGES", value: String(p.achievements.length) },
      ]
    : [];

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          padding: 64,
          color: "#fff",
          backgroundColor: "#09090B",
          backgroundImage:
            "radial-gradient(circle at 12% 0%, rgba(139,92,246,0.55), transparent 45%), radial-gradient(circle at 95% 10%, rgba(34,211,238,0.45), transparent 42%)",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 18 }}>
          <svg width="56" height="56" viewBox="0 0 512 512">
            <path fill="#fff" fillRule="evenodd" d={BRAND_MARK_PATH} />
          </svg>
          <div style={{ display: "flex", fontSize: 30, fontWeight: 600, letterSpacing: 4 }}>CONSINZO</div>
        </div>

        <div style={{ display: "flex", flexDirection: "column" }}>
          <div style={{ display: "flex", fontSize: p ? 76 : 60, fontWeight: 700, lineHeight: 1.05 }}>
            {p ? p.displayName.slice(0, 28) : "Developer not found"}
          </div>
          {p ? (
            <div style={{ display: "flex", marginTop: 12, fontSize: 30, color: "#a1a1aa" }}>
              @{p.username} · smart-contract engineer
            </div>
          ) : null}
        </div>

        <div style={{ display: "flex", gap: 20 }}>
          {stats.map((s) => (
            <div
              key={s.label}
              style={{
                display: "flex",
                flexDirection: "column",
                flex: 1,
                padding: "20px 24px",
                borderRadius: 20,
                border: "1px solid rgba(255,255,255,0.14)",
                background: "rgba(255,255,255,0.05)",
              }}
            >
              <div style={{ display: "flex", fontSize: 46, fontWeight: 700 }}>{s.value}</div>
              <div style={{ display: "flex", marginTop: 4, fontSize: 17, letterSpacing: 2, color: "#a1a1aa" }}>
                {s.label}
              </div>
            </div>
          ))}
        </div>
      </div>
    ),
    size
  );
}
