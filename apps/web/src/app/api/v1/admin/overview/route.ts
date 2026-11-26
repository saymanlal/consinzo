import crypto from "node:crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { requireAdminRole } from "@/lib/auth";
import { listPublishedChallenges } from "@/lib/challenges";
import { handleApiError } from "@/lib/http";
import { readDb, writeDb } from "@/lib/store";

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
    const db = readDb();
    const challenges = listPublishedChallenges();
    return NextResponse.json({
      stats: {
        registeredUsers: db.users.length,
        publishedChallenges: challenges.length,
        totalSubmissions: db.submissions.length,
        pendingAuditReports: db.auditReports.filter((r) => r.status === "submitted").length,
      },
      recentSubmissions: db.submissions.slice(0, 20),
      auditReports: db.auditReports,
      auditLogs: db.adminAuditLogs.slice(0, 30),
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
    const db = readDb();
    const report = db.auditReports.find((r) => r.id === body.reportId);
    if (!report) {
      return NextResponse.json(
        { error: { code: "NOT_FOUND", message: "Audit report not found." } },
        { status: 404 }
      );
    }

    report.status = body.decision;
    report.reviewerFeedback = body.feedback;
    db.adminAuditLogs.unshift({
      id: crypto.randomUUID(),
      actorId: reviewer.id,
      action: `audit_report.${body.decision}`,
      targetType: "audit_report",
      targetId: report.id,
      metadata: { missionSlug: report.missionSlug },
      createdAt: new Date().toISOString(),
    });
    writeDb(db);
    return NextResponse.json({ report });
  } catch (err) {
    return handleApiError(err);
  }
}
