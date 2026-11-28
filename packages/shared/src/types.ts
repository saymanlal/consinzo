export type RoleName =
  | "developer"
  | "content_editor"
  | "competition_organizer"
  | "security_reviewer"
  | "ecosystem_manager"
  | "challenge_manager"
  | "platform_admin"
  | "super_admin";

export type Difficulty = "beginner" | "easy" | "normal" | "intermediate" | "hard" | "legend";

export type ChallengeCategory =
  | "programming-fundamentals"
  | "smart-contract-engineering"
  | "protocol-implementation"
  | "defi-engineering"
  | "token-standards"
  | "blockchain-infrastructure"
  | "advanced-blockchain-systems"
  | "security-engineering"
  | "cross-chain-development"
  | "ecosystem-integrations";

export type PublicationStatus = "draft" | "in_review" | "published" | "archived";

export type ExecutionMode = "browser-worker" | "local-cli" | "remote-actions";

export type SubmissionStatus =
  | "queued"
  | "compiling"
  | "running"
  | "passed"
  | "failed"
  | "compilation_error"
  | "timeout"
  | "quota_exceeded"
  | "cancelled";

export interface ProjectFile {
  path: string;
  content: string;
  readOnly?: boolean;
}

export interface ApiErrorShape {
  error: {
    code: string;
    message: string;
    details?: unknown;
    requestId?: string;
  };
}
