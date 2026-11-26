export default function WorkspaceLoading() {
  return (
    <div className="min-h-[calc(100vh-3.5rem)] bg-[#0C0E12] p-4 animate-pulse">
      <div className="h-10 rounded bg-zinc-900 mb-4" />
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-4 h-[75vh]">
        <div className="lg:col-span-3 rounded bg-zinc-900" />
        <div className="lg:col-span-6 rounded bg-zinc-900" />
        <div className="lg:col-span-3 rounded bg-zinc-900" />
      </div>
    </div>
  );
}
