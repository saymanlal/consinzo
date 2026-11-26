import { notFound } from "next/navigation";
import { getPublicChallengeBySlug } from "@/lib/challenges";
import { IdeWorkspace } from "@/components/ide-workspace";

export default async function WorkspacePage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const challenge = getPublicChallengeBySlug(slug);
  if (!challenge) notFound();

  return <IdeWorkspace challenge={challenge} />;
}
