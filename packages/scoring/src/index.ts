export interface ScoringWeights {
  functional_correctness: number;
  security_invariants: number;
  efficiency: number;
  code_quality: number;
}

export interface TestCaseOutcome {
  name: string;
  passed: boolean;
  suite: "public" | "hidden";
  gasUsed?: number;
  durationMs?: number;
  errorMessage?: string;
}

export interface ScoringInput {
  maxPoints: number;
  weights: ScoringWeights;
  publicResults: TestCaseOutcome[];
  hiddenResults: TestCaseOutcome[];
  compilerWarningsCount: number;
  gasBudget?: number;
  averageGasUsed?: number;
  compiled: boolean;
}

export interface SanitizedScoringBreakdown {
  totalScore: number;
  maxPoints: number;
  passed: boolean;
  components: {
    functionalCorrectness: number;
    securityInvariants: number;
    efficiency: number;
    codeQuality: number;
  };
  publicSummary: {
    total: number;
    passed: number;
    failed: number;
  };
  // Hidden test names and raw hidden errors are intentionally omitted to prevent leakage.
  hiddenSummary: {
    evaluated: boolean;
    total: number;
    passed: number;
    failed: number;
  };
}

export function calculateScore(input: ScoringInput): SanitizedScoringBreakdown {
  const pubTotal = input.publicResults.length;
  const pubPassed = input.publicResults.filter((t) => t.passed).length;
  const hidTotal = input.hiddenResults.length;
  const hidPassed = input.hiddenResults.filter((t) => t.passed).length;

  if (!input.compiled) {
    return {
      totalScore: 0,
      maxPoints: input.maxPoints,
      passed: false,
      components: {
        functionalCorrectness: 0,
        securityInvariants: 0,
        efficiency: 0,
        codeQuality: 0,
      },
      publicSummary: { total: pubTotal, passed: 0, failed: pubTotal },
      hiddenSummary: {
        evaluated: hidTotal > 0,
        total: hidTotal,
        passed: 0,
        failed: hidTotal,
      },
    };
  }

  const funcRatio = pubTotal > 0 ? pubPassed / pubTotal : 0;
  const secRatio = hidTotal > 0 ? hidPassed / hidTotal : funcRatio;

  let effRatio = 0;
  if (funcRatio === 1 && secRatio === 1) {
    if (input.gasBudget && input.averageGasUsed && input.averageGasUsed > 0) {
      effRatio = input.averageGasUsed <= input.gasBudget ? 1 : Math.max(0.4, input.gasBudget / input.averageGasUsed);
    } else {
      effRatio = 1;
    }
  }

  const qualityRatio =
    funcRatio === 1 ? Math.max(0.5, 1 - input.compilerWarningsCount * 0.15) : 0;

  const { weights, maxPoints } = input;
  const fcPts = (weights.functional_correctness / 100) * maxPoints * funcRatio;
  const secPts = (weights.security_invariants / 100) * maxPoints * secRatio;
  const effPts = (weights.efficiency / 100) * maxPoints * effRatio;
  const qualPts = (weights.code_quality / 100) * maxPoints * qualityRatio;

  const totalScore = Math.round((fcPts + secPts + effPts + qualPts) * 100) / 100;
  const allPublicPassed = pubTotal > 0 && pubPassed === pubTotal;
  const allHiddenPassed = hidTotal === 0 || hidPassed === hidTotal;

  return {
    totalScore,
    maxPoints,
    passed: allPublicPassed && allHiddenPassed,
    components: {
      functionalCorrectness: Math.round(fcPts * 100) / 100,
      securityInvariants: Math.round(secPts * 100) / 100,
      efficiency: Math.round(effPts * 100) / 100,
      codeQuality: Math.round(qualPts * 100) / 100,
    },
    publicSummary: {
      total: pubTotal,
      passed: pubPassed,
      failed: pubTotal - pubPassed,
    },
    hiddenSummary: {
      evaluated: hidTotal > 0,
      total: hidTotal,
      passed: hidPassed,
      failed: hidTotal - hidPassed,
    },
  };
}
