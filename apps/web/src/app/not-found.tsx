import Link from "next/link";

export default function NotFound() {
  return (
    <div className="mx-auto flex max-w-2xl flex-col items-start justify-center px-6 py-24">
      <p className="font-mono text-xs uppercase tracking-wider text-zinc-500">404 / Not Found</p>
      <h1 className="mt-2 text-2xl font-semibold text-zinc-950">Resource does not exist</h1>
      <p className="mt-2 text-sm text-zinc-600">
        The requested challenge, ecosystem, or engineering route could not be located.
      </p>
      <Link
        href="/"
        className="mt-6 rounded-md bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800"
      >
        Return to Overview
      </Link>
    </div>
  );
}
