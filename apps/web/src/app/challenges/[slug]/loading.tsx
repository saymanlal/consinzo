export default function ChallengeDetailLoading() {
  return (
    <div className="mx-auto max-w-6xl px-4 py-8 lg:px-6 space-y-6 animate-pulse">
      <div className="border-b border-zinc-200 pb-6 space-y-3">
        <div className="h-5 w-48 rounded bg-zinc-200" />
        <div className="h-8 w-2/3 rounded bg-zinc-200" />
        <div className="h-4 w-1/2 rounded bg-zinc-200" />
      </div>
      <div className="grid gap-6 lg:grid-cols-3">
        <div className="lg:col-span-2 h-80 rounded-lg border border-zinc-200 bg-white" />
        <div className="h-80 rounded-lg border border-zinc-200 bg-white" />
      </div>
    </div>
  );
}
