"use client";

import React, { useEffect, useRef, useState } from "react";

function prefersReducedMotion() {
  return (
    typeof window !== "undefined" &&
    window.matchMedia?.("(prefers-reduced-motion: reduce)").matches === true
  );
}

/** Fades and lifts its children into place the first time they scroll into view. */
export function Reveal({
  children,
  delay = 0,
  className = "",
  as: Tag = "div",
}: {
  children: React.ReactNode;
  delay?: number;
  className?: string;
  as?: "div" | "section" | "li" | "article";
}) {
  const ref = useRef<HTMLElement | null>(null);
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el || typeof IntersectionObserver === "undefined") {
      setVisible(true);
      return;
    }
    const io = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) {
          setVisible(true);
          io.disconnect();
        }
      },
      { rootMargin: "0px 0px -8% 0px", threshold: 0.08 }
    );
    io.observe(el);
    return () => io.disconnect();
  }, []);

  return React.createElement(
    Tag,
    {
      ref,
      className: `cz-reveal ${visible ? "is-visible" : ""} ${className}`,
      style: { "--cz-delay": `${delay}ms` } as React.CSSProperties,
    },
    children
  );
}

/** Counts up to `value` once visible. Renders the final value on the server and without motion. */
export function CountUp({
  value,
  suffix = "",
  duration = 1400,
}: {
  value: number;
  suffix?: string;
  duration?: number;
}) {
  const ref = useRef<HTMLSpanElement | null>(null);
  const [display, setDisplay] = useState(value);

  useEffect(() => {
    const el = ref.current;
    if (!el || prefersReducedMotion() || typeof IntersectionObserver === "undefined") return;
    // Timer-driven (not requestAnimationFrame) so a throttled or background tab still ends
    // on the true value instead of freezing part-way.
    let timer: ReturnType<typeof setInterval> | undefined;
    const io = new IntersectionObserver((entries) => {
      if (!entries.some((e) => e.isIntersecting)) return;
      io.disconnect();
      const steps = Math.max(1, Math.round(duration / 32));
      let step = 0;
      setDisplay(0);
      timer = setInterval(() => {
        step += 1;
        const t = Math.min(1, step / steps);
        setDisplay(Math.round(value * (1 - Math.pow(1 - t, 3))));
        if (t >= 1) clearInterval(timer);
      }, 32);
    });
    io.observe(el);
    return () => {
      io.disconnect();
      clearInterval(timer);
      setDisplay(value);
    };
  }, [value, duration]);

  return (
    <span ref={ref} className="tabular-nums">
      {display.toLocaleString("en-US")}
      {suffix}
    </span>
  );
}

export interface TerminalLine {
  text: string;
  tone?: "cmd" | "ok" | "fail" | "muted" | "accent";
}

const TONE: Record<NonNullable<TerminalLine["tone"]>, string> = {
  cmd: "text-white",
  ok: "text-emerald-400",
  fail: "text-rose-400",
  muted: "text-zinc-500",
  accent: "text-cyan-300",
};

/** Types out a scripted terminal session line by line, then loops. Purely illustrative. */
export function TerminalDemo({ lines, title }: { lines: TerminalLine[]; title: string }) {
  const [count, setCount] = useState(lines.length);
  const [typed, setTyped] = useState("");

  useEffect(() => {
    if (prefersReducedMotion()) return;
    let cancelled = false;
    let timer: ReturnType<typeof setTimeout>;
    const wait = (ms: number) =>
      new Promise<void>((resolve) => {
        timer = setTimeout(resolve, ms);
      });

    (async () => {
      while (!cancelled) {
        setCount(0);
        setTyped("");
        for (let i = 0; i < lines.length && !cancelled; i++) {
          const line = lines[i]!;
          if (line.tone === "cmd") {
            for (let c = 1; c <= line.text.length && !cancelled; c++) {
              setTyped(line.text.slice(0, c));
              await wait(28);
            }
            await wait(320);
            setTyped("");
          } else {
            await wait(260);
          }
          setCount(i + 1);
        }
        await wait(4200);
      }
    })();

    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [lines]);

  const typingLine = count < lines.length && lines[count]?.tone === "cmd";

  return (
    <div className="cz-card overflow-hidden text-left shadow-2xl shadow-black/60">
      <div className="flex items-center gap-2 border-b border-white/10 px-4 py-2.5">
        <span className="h-2.5 w-2.5 rounded-full bg-rose-400/80" />
        <span className="h-2.5 w-2.5 rounded-full bg-amber-300/80" />
        <span className="h-2.5 w-2.5 rounded-full bg-emerald-400/80" />
        <span className="ml-2 truncate font-mono text-[11px] text-zinc-500">{title}</span>
      </div>
      <pre
        aria-label="Example test run"
        className="min-h-[15.5rem] overflow-x-auto px-4 py-4 font-mono text-[12px] leading-relaxed sm:text-[13px]"
      >
        {lines.slice(0, count).map((l, i) => (
          <div key={i} className={TONE[l.tone ?? "muted"]}>
            {l.tone === "cmd" ? <span className="text-cyan-400">$ </span> : null}
            {l.text}
          </div>
        ))}
        {count < lines.length || typingLine ? (
          <div className="text-white">
            {typingLine ? <span className="text-cyan-400">$ </span> : null}
            {typed}
            <span className="cz-caret" />
          </div>
        ) : (
          <div className="text-white">
            <span className="text-cyan-400">$ </span>
            <span className="cz-caret" />
          </div>
        )}
      </pre>
    </div>
  );
}
