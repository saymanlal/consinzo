export default function ChallengesLoading() {
  return (
    <div className="mx-auto max-w-[1440px] px-4 py-8 lg:px-6 space-y-6 animate-pulse">
      <div className="h-8 w-64 rounded bg-zinc-200" />
      <div className="h-16 rounded-lg border border-zinc-200 bg-white" />
      <div className="grid gap-4 md:grid-cols-3">
        {[1, 2, 3, 4, 5, 6].map((i) => (
          <div key={i} className="h-52 rounded-lg border border-zinc-200 bg-white" />
        ))}
      </div>
    </div>
  );
}
