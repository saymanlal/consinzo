import type { ChallengeManifest, PublicChallengeView } from "@consinzo/challenge-spec";

export interface ChallengeFileEntry {
  path: string;
  content: string;
  readOnly: boolean;
}

export interface RelatedChallengeSummary {
  id: string;
  slug: string;
  title: string;
  ecosystem: string;
  difficulty: string;
  category: string;
  maxPoints: number;
}

export type ChallengeLoadErrorKind =
  | "not_found"
  | "unpublished"
  | "incomplete"
  | "storage_error"
  | "invalid_slug";

export type ChallengeLoadResult =
  | {
      status: "ok";
      data: PublicChallengeView;
    }
  | {
      status: "error";
      kind: ChallengeLoadErrorKind;
      message: string;
      recoverable: boolean;
    };

export type ChallengeListResult =
  | {
      status: "ok";
      challenges: ChallengeManifest[];
    }
  | {
      status: "error";
      kind: "storage_error";
      message: string;
    };
