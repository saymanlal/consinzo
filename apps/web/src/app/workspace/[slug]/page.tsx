import { notFound } from "next/navigation";
import { getEcosystemById } from "@consinzo/ecosystem-registry";
import { ChallengeErrorState } from "@/components/challenge-error-state";
import { IdeWorkspace } from "@/components/ide-workspace";
import { getChallengeBySlug, getPublishedChallenges } from "@/lib/challenges";

export const dynamicParams = true;

export function generateStaticParams() {
  return getPublishedChallenges().map((c) => ({ slug: c.slug }));
}

export default async function WorkspacePage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const outcome = getChallengeBySlug(slug);

  if (outcome.status === "error") {
    if (
      outcome.kind === "not_found" ||
      outcome.kind === "invalid_slug" ||
      outcome.kind === "unpublished"
    ) {
      notFound();
    }
    if (outcome.kind === "storage_error") {
      return (
        <ChallengeErrorState
          code="STORAGE_UNAVAILABLE"
          title="Workspace storage unavailable"
          message={outcome.message}
          recoverable={true}
        />
      );
    }
    return (
      <ChallengeErrorState
        code="STARTER_UNAVAILABLE"
        title="Starter project is incomplete"
        message={outcome.message}
        recoverable={false}
      />
    );
  }

  const eco = getEcosystemById(outcome.data.manifest.ecosystem);
  if (!eco || !eco.capabilities.localCliTest) {
    return (
      <ChallengeErrorState
        code="ECOSYSTEM_UNSUPPORTED"
        title={`Execution for ${eco?.name ?? outcome.data.manifest.ecosystem} is not yet enabled`}
        message="This ecosystem is currently at reference/syntax support level and does not have an executable runner enabled."
        recoverable={false}
      />
    );
  }

  return <IdeWorkspace challenge={outcome.data} />;
}
