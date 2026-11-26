import { Card } from "@consinzo/ui";

export default function AboutPage() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-10 space-y-6">
      <h1 className="text-2xl font-semibold text-zinc-950">About CONSINZO</h1>
      <Card className="p-6 space-y-3 text-sm leading-relaxed text-zinc-700">
        <p>
          <strong>CONSINZO</strong> is a proprietary, closed-source engineering and developer
          technology platform built for practical blockchain and smart-contract engineering.
        </p>
        <p>
          Rather than static multiple-choice quizzes or toy sandboxes, CONSINZO centers on native
          compilation, adversarial testing, security exploit reproduction, and verifiable
          engineering progression.
        </p>
        <p className="text-xs text-zinc-500">
          Copyright (c) 2026 CONSINZO. All Rights Reserved. Public access to the web platform does
          not grant open-source rights to its source code, evaluation engine, or proprietary
          challenge suites.
        </p>
      </Card>
    </div>
  );
}
