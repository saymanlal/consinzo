import { NextResponse } from "next/server";
import { z } from "zod";
import { requireAdminRole } from "@/lib/auth";
import { listPublishedChallenges } from "@/lib/challenges";
import { getAdminStatsSnapshot, reviewAuditReport } from "@/lib/data-adapter";
import { handleApiError } from "@/lib/http";

const ReviewActionSchema = z.object({
  reportId: z.string().uuid(),
  decision: z.enum(["accepted", "needs_revision"]),
  feedback: z.string().min(5).max(1000),
});

export async function GET() {
  try {
    await requireAdminRole([
      "super_admin",
      "platform_admin",
      "challenge_manager",
      "security_reviewer",
    ]);
    const snapshot = await getAdminStatsSnapshot();
    const challenges = listPublishedChallenges();
    return NextResponse.json({
      stats: {
        registeredUsers: snapshot.registeredUsers,
        publishedChallenges: challenges.length,
        totalSubmissions: snapshot.totalSubmissions,
        pendingAuditReports: snapshot.pendingAuditReports,
      },
      recentSubmissions: snapshot.recentSubmissions,
      auditReports: snapshot.auditReports,
      auditLogs: snapshot.auditLogs,
    });
  } catch (err) {
    return handleApiError(err);
  }
}

export async function POST(req: Request) {
  try {
    const reviewer = await requireAdminRole([
      "super_admin",
      "platform_admin",
      "security_reviewer",
    ]);
    const body = ReviewActionSchema.parse(await req.json());
    const report = await reviewAuditReport({
      reportId: body.reportId,
      reviewerId: reviewer.id,
      decision: body.decision,
      feedback: body.feedback,
    });
    if (!report) {
      return NextResponse.json(
        { error: { code: "NOT_FOUND", message: "Audit report not found." } },
        { status: 404 }
      );
    }
    return NextResponse.json({ report });
  } catch (err) {
    return handleApiError(err);
  }
}
