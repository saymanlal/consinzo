"use client";

import React, { useMemo, useState } from "react";
import { AlertTriangle, CheckCircle2, Sliders } from "lucide-react";
import { Badge, Card } from "@consinzo/ui";

type SimulatorTab = "amm" | "vault" | "auction";

export function ProtocolSimulators() {
  const [tab, setTab] = useState<SimulatorTab>("amm");

  // 1. Constant-Product AMM state
  const [reserveX, setReserveX] = useState(1000);
  const [reserveY, setReserveY] = useState(2000000);
  const [feeBps, setFeeBps] = useState(30);
  const [amountIn, setAmountIn] = useState(50);

  const ammStats = useMemo(() => {
    const k = reserveX * reserveY;
    const spotBefore = reserveY / reserveX;
    const effectiveIn = amountIn * (1 - feeBps / 10000);
    const nextX = reserveX + amountIn;
    const nextY = (reserveX * reserveY) / (reserveX + effectiveIn);
    const amountOut = Math.max(0, reserveY - nextY);
    const execPrice = amountIn > 0 ? amountOut / amountIn : spotBefore;
    const priceImpactPct =
      spotBefore > 0 ? Math.max(0, ((spotBefore - execPrice) / spotBefore) * 100) : 0;
    const spotAfter = nextY / nextX;
    const nextK = nextX * nextY;
    return {
      k,
      spotBefore,
      spotAfter,
      amountOut,
      execPrice,
      priceImpactPct,
      feePaid: amountIn - effectiveIn,
      nextK,
    };
  }, [reserveX, reserveY, feeBps, amountIn]);

  // 2. ERC-4626 Donation / First-Depositor Attack state
  const [donationAmount, setDonationAmount] = useState(10000);
  const [victimDeposit, setVictimDeposit] = useState(8000);
  const [mitigated, setMitigated] = useState(false);

  const vaultStats = useMemo(() => {
    const attackerSeed = 1;
    const virtualOffset = mitigated ? 1000 : 0;
    const initialSupply = attackerSeed + virtualOffset;
    const initialAssets = attackerSeed + donationAmount + virtualOffset;

    const victimShares = Math.floor((victimDeposit * initialSupply) / initialAssets);
    const totalSupplyAfter = initialSupply + victimShares;
    const totalAssetsAfter = initialAssets + victimDeposit;

    const attackerRedeemValue = Math.floor((attackerSeed * totalAssetsAfter) / totalSupplyAfter);
    const victimRedeemValue = Math.floor((victimShares * totalAssetsAfter) / totalSupplyAfter);
    const victimLoss = Math.max(0, victimDeposit - victimRedeemValue);

    return {
      victimShares,
      attackerRedeemValue,
      victimRedeemValue,
      victimLoss,
      sharePriceRatio: initialAssets / initialSupply,
    };
  }, [donationAmount, victimDeposit, mitigated]);

  // 3. Dutch Auction Decay state
  const [startPrice, setStartPrice] = useState(500);
  const [reservePrice, setReservePrice] = useState(80);
  const [durationSec, setDurationSec] = useState(3600);
  const [elapsedSec, setElapsedSec] = useState(1440);
  const [bidUnits, setBidUnits] = useState(3);

  const auctionStats = useMemo(() => {
    const clampedElapsed = Math.min(Math.max(0, elapsedSec), durationSec);
    const progress = durationSec > 0 ? clampedElapsed / durationSec : 1;
    const currentPrice = startPrice - (startPrice - reservePrice) * progress;
    const totalCost = currentPrice * bidUnits;
    const pctDiscount = startPrice > 0 ? ((startPrice - currentPrice) / startPrice) * 100 : 0;
    return {
      clampedElapsed,
      progress,
      currentPrice,
      totalCost,
      pctDiscount,
    };
  }, [startPrice, reservePrice, durationSec, elapsedSec, bidUnits]);

  return (
    <Card className="p-6 border-zinc-200 bg-white">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between border-b border-zinc-200 pb-4">
        <div>
          <div className="flex items-center gap-2">
            <Sliders className="h-4 w-4 text-blue-700" />
            <h2 className="text-base font-semibold text-zinc-950">
              Interactive DeFi &amp; Protocol Invariant Simulators
            </h2>
          </div>
          <p className="mt-1 text-xs text-zinc-600">
            Explore live state transitions, slippage math, and economic attack vectors directly in
            your browser before writing Solidity or TypeScript contract implementations.
          </p>
        </div>

        <div className="flex flex-wrap gap-1.5">
          {(
            [
              { id: "amm", label: "AMM (x·y = k)" },
              { id: "vault", label: "ERC-4626 Inflation" },
              { id: "auction", label: "Dutch Auction Decay" },
            ] as const
          ).map((item) => (
            <button
              key={item.id}
              type="button"
              onClick={() => setTab(item.id)}
              className={`rounded-md px-3 py-1.5 text-xs font-medium transition ${
                tab === item.id
                  ? "bg-zinc-950 text-white"
                  : "border border-zinc-200 bg-zinc-50 text-zinc-700 hover:bg-zinc-100"
              }`}
            >
              {item.label}
            </button>
          ))}
        </div>
      </div>

      {tab === "amm" && (
        <div className="mt-5 grid gap-6 lg:grid-cols-2">
          <div className="space-y-4">
            <label className="block text-xs">
              <div className="flex justify-between font-medium text-zinc-700">
                <span>Pool Reserve X (ETH)</span>
                <span className="font-mono text-zinc-950">{reserveX.toLocaleString()}</span>
              </div>
              <input
                type="range"
                min={50}
                max={5000}
                step={50}
                value={reserveX}
                onChange={(e) => setReserveX(Number(e.target.value))}
                className="mt-1.5 w-full accent-blue-700"
              />
            </label>

            <label className="block text-xs">
              <div className="flex justify-between font-medium text-zinc-700">
                <span>Pool Reserve Y (USDC)</span>
                <span className="font-mono text-zinc-950">{reserveY.toLocaleString()}</span>
              </div>
              <input
                type="range"
                min={50000}
                max={10000000}
                step={50000}
                value={reserveY}
                onChange={(e) => setReserveY(Number(e.target.value))}
                className="mt-1.5 w-full accent-blue-700"
              />
            </label>

            <label className="block text-xs">
              <div className="flex justify-between font-medium text-zinc-700">
                <span>Swap Input Δx (ETH)</span>
                <span className="font-mono text-zinc-950">{amountIn.toLocaleString()} ETH</span>
              </div>
              <input
                type="range"
                min={1}
                max={Math.max(10, Math.floor(reserveX * 0.8))}
                step={1}
                value={amountIn}
                onChange={(e) => setAmountIn(Number(e.target.value))}
                className="mt-1.5 w-full accent-blue-700"
              />
            </label>

            <label className="block text-xs">
              <div className="flex justify-between font-medium text-zinc-700">
                <span>Protocol Fee (bps)</span>
                <span className="font-mono text-zinc-950">
                  {feeBps} bps ({(feeBps / 100).toFixed(2)}%)
                </span>
              </div>
              <input
                type="range"
                min={0}
                max={100}
                step={5}
                value={feeBps}
                onChange={(e) => setFeeBps(Number(e.target.value))}
                className="mt-1.5 w-full accent-blue-700"
              />
            </label>
          </div>

          <div className="rounded-lg border border-zinc-200 bg-zinc-50 p-4 space-y-3 text-xs">
            <div className="flex items-center justify-between">
              <span className="font-semibold text-zinc-900">Simulated Swap Execution</span>
              <Badge tone={ammStats.priceImpactPct > 5 ? "amber" : "green"}>
                Impact: {ammStats.priceImpactPct.toFixed(2)}%
              </Badge>
            </div>
            <div className="grid grid-cols-2 gap-3 font-mono">
              <div className="rounded border border-zinc-200 bg-white p-2.5">
                <div className="text-[11px] text-zinc-500">Output Received (Δy)</div>
                <div className="mt-0.5 text-sm font-semibold text-zinc-950">
                  {ammStats.amountOut.toFixed(2)} USDC
                </div>
              </div>
              <div className="rounded border border-zinc-200 bg-white p-2.5">
                <div className="text-[11px] text-zinc-500">Effective Fill Price</div>
                <div className="mt-0.5 text-sm font-semibold text-zinc-950">
                  {ammStats.execPrice.toFixed(2)} USDC/ETH
                </div>
              </div>
              <div className="rounded border border-zinc-200 bg-white p-2.5">
                <div className="text-[11px] text-zinc-500">Spot Before → After</div>
                <div className="mt-0.5 text-zinc-900">
                  {ammStats.spotBefore.toFixed(1)} → {ammStats.spotAfter.toFixed(1)}
                </div>
              </div>
              <div className="rounded border border-zinc-200 bg-white p-2.5">
                <div className="text-[11px] text-zinc-500">LP Fee Retained</div>
                <div className="mt-0.5 text-zinc-900">{ammStats.feePaid.toFixed(4)} ETH</div>
              </div>
            </div>
            <p className="text-[11px] text-zinc-600 leading-relaxed">
              Because fees stay inside the pool, the new invariant{" "}
              <code className="font-mono">k&apos; = {Math.round(ammStats.nextK).toLocaleString()}</code>{" "}
              strictly satisfies <code className="font-mono">k&apos; &gt;= k</code> (
              {Math.round(ammStats.k).toLocaleString()}).
            </p>
          </div>
        </div>
      )}

      {tab === "vault" && (
        <div className="mt-5 grid gap-6 lg:grid-cols-2">
          <div className="space-y-4">
            <div className="flex items-center justify-between rounded-md border border-zinc-200 bg-zinc-50 p-3">
              <div>
                <div className="text-xs font-semibold text-zinc-950">Defense Mode</div>
                <div className="text-[11px] text-zinc-600">
                  Toggle naive vault vs virtual-shares offset protection
                </div>
              </div>
              <button
                type="button"
                onClick={() => setMitigated((v) => !v)}
                className={`rounded-md px-3 py-1.5 text-xs font-semibold transition ${
                  mitigated
                    ? "bg-emerald-700 text-white"
                    : "bg-red-700 text-white"
                }`}
              >
                {mitigated ? "Mitigated (Virtual Offset)" : "Vulnerable (Naive)"}
              </button>
            </div>

            <label className="block text-xs">
              <div className="flex justify-between font-medium text-zinc-700">
                <span>Step 2: Attacker Direct Asset Donation</span>
                <span className="font-mono text-zinc-950">
                  {donationAmount.toLocaleString()} assets
                </span>
              </div>
              <input
                type="range"
                min={0}
                max={50000}
                step={500}
                value={donationAmount}
                onChange={(e) => setDonationAmount(Number(e.target.value))}
                className="mt-1.5 w-full accent-blue-700"
              />
            </label>

            <label className="block text-xs">
              <div className="flex justify-between font-medium text-zinc-700">
                <span>Step 3: Victim Subsequent Deposit</span>
                <span className="font-mono text-zinc-950">
                  {victimDeposit.toLocaleString()} assets
                </span>
              </div>
              <input
                type="range"
                min={100}
                max={50000}
                step={100}
                value={victimDeposit}
                onChange={(e) => setVictimDeposit(Number(e.target.value))}
                className="mt-1.5 w-full accent-blue-700"
              />
            </label>
          </div>

          <div className="rounded-lg border border-zinc-200 bg-zinc-50 p-4 space-y-3 text-xs">
            <div className="flex items-center justify-between">
              <span className="font-semibold text-zinc-900">ERC-4626 Rounding Outcome</span>
              {vaultStats.victimLoss > 0 ? (
                <Badge tone="red" className="gap-1">
                  <AlertTriangle className="h-3 w-3" />
                  Victim Loses {vaultStats.victimLoss.toLocaleString()}
                </Badge>
              ) : (
                <Badge tone="green" className="gap-1">
                  <CheckCircle2 className="h-3 w-3" />
                  Protected
                </Badge>
              )}
            </div>
            <div className="grid grid-cols-2 gap-3 font-mono">
              <div className="rounded border border-zinc-200 bg-white p-2.5">
                <div className="text-[11px] text-zinc-500">Shares Minted to Victim</div>
                <div className="mt-0.5 text-sm font-semibold text-zinc-950">
                  {vaultStats.victimShares.toLocaleString()}
                </div>
              </div>
              <div className="rounded border border-zinc-200 bg-white p-2.5">
                <div className="text-[11px] text-zinc-500">Victim Redeemable Value</div>
                <div className="mt-0.5 text-sm font-semibold text-zinc-950">
                  {vaultStats.victimRedeemValue.toLocaleString()}
                </div>
              </div>
              <div className="rounded border border-zinc-200 bg-white p-2.5">
                <div className="text-[11px] text-zinc-500">Attacker 1-Share Redeem</div>
                <div className="mt-0.5 text-zinc-900">
                  {vaultStats.attackerRedeemValue.toLocaleString()}
                </div>
              </div>
              <div className="rounded border border-zinc-200 bg-white p-2.5">
                <div className="text-[11px] text-zinc-500">Inflated Share Price</div>
                <div className="mt-0.5 text-zinc-900">
                  {vaultStats.sharePriceRatio.toFixed(2)}x
                </div>
              </div>
            </div>
            <p className="text-[11px] text-zinc-600 leading-relaxed">
              When total supply is 1 share and the attacker donates{" "}
              {donationAmount.toLocaleString()} assets directly, integer division rounds victim
              shares down to <code className="font-mono">0</code> whenever{" "}
              <code className="font-mono">victimDeposit &lt; sharePrice</code>. Virtual offset
              shares make this attack prohibitively expensive.
            </p>
          </div>
        </div>
      )}

      {tab === "auction" && (
        <div className="mt-5 grid gap-6 lg:grid-cols-2">
          <div className="space-y-4">
            <label className="block text-xs">
              <div className="flex justify-between font-medium text-zinc-700">
                <span>Start Price (USDC)</span>
                <span className="font-mono text-zinc-950">{startPrice} USDC</span>
              </div>
              <input
                type="range"
                min={200}
                max={2000}
                step={20}
                value={startPrice}
                onChange={(e) => {
                  const v = Number(e.target.value);
                  setStartPrice(v);
                  if (v <= reservePrice) setReservePrice(Math.max(20, v - 40));
                }}
                className="mt-1.5 w-full accent-blue-700"
              />
            </label>

            <label className="block text-xs">
              <div className="flex justify-between font-medium text-zinc-700">
                <span>Reserve Floor Price (USDC)</span>
                <span className="font-mono text-zinc-950">{reservePrice} USDC</span>
              </div>
              <input
                type="range"
                min={20}
                max={Math.max(40, startPrice - 20)}
                step={10}
                value={reservePrice}
                onChange={(e) => setReservePrice(Number(e.target.value))}
                className="mt-1.5 w-full accent-blue-700"
              />
            </label>

            <label className="block text-xs">
              <div className="flex justify-between font-medium text-zinc-700">
                <span>Elapsed Auction Time (sec / {durationSec}s)</span>
                <span className="font-mono text-zinc-950">
                  {auctionStats.clampedElapsed}s ({(auctionStats.progress * 100).toFixed(0)}%)
                </span>
              </div>
              <input
                type="range"
                min={0}
                max={durationSec}
                step={60}
                value={elapsedSec}
                onChange={(e) => setElapsedSec(Number(e.target.value))}
                className="mt-1.5 w-full accent-blue-700"
              />
            </label>

            <label className="block text-xs">
              <div className="flex justify-between font-medium text-zinc-700">
                <span>Units to Purchase</span>
                <span className="font-mono text-zinc-950">{bidUnits} units</span>
              </div>
              <input
                type="range"
                min={1}
                max={10}
                step={1}
                value={bidUnits}
                onChange={(e) => setBidUnits(Number(e.target.value))}
                className="mt-1.5 w-full accent-blue-700"
              />
            </label>
          </div>

          <div className="rounded-lg border border-zinc-200 bg-zinc-50 p-4 space-y-3 text-xs">
            <div className="flex items-center justify-between">
              <span className="font-semibold text-zinc-900">Linear Clearing Schedule</span>
              <Badge tone="blue">-{auctionStats.pctDiscount.toFixed(1)}% from ceiling</Badge>
            </div>

            <svg
              viewBox="0 0 300 100"
              className="w-full h-24 rounded border border-zinc-200 bg-white"
              aria-label="Dutch auction price decay curve"
            >
              <line x1="20" y1="15" x2="280" y2="85" stroke="#1d4ed8" strokeWidth="2.5" />
              <line
                x1="20"
                y1="85"
                x2="280"
                y2="85"
                stroke="#d4d4d8"
                strokeWidth="1"
                strokeDasharray="4 4"
              />
              <circle
                cx={20 + 260 * auctionStats.progress}
                cy={15 + 70 * auctionStats.progress}
                r="5"
                fill="#1d4ed8"
              />
            </svg>

            <div className="grid grid-cols-2 gap-3 font-mono">
              <div className="rounded border border-zinc-200 bg-white p-2.5">
                <div className="text-[11px] text-zinc-500">Current Unit Price</div>
                <div className="mt-0.5 text-sm font-semibold text-zinc-950">
                  {auctionStats.currentPrice.toFixed(2)} USDC
                </div>
              </div>
              <div className="rounded border border-zinc-200 bg-white p-2.5">
                <div className="text-[11px] text-zinc-500">
                  Required msg.value ({bidUnits} units)
                </div>
                <div className="mt-0.5 text-sm font-semibold text-zinc-950">
                  {auctionStats.totalCost.toFixed(2)} USDC
                </div>
              </div>
            </div>
            <p className="text-[11px] text-zinc-600">
              Adjust duration or start price cleanly and verify{" "}
              <code className="font-mono">msg.value &gt;= cost</code> with immediate excess refund
              to prevent stuck bidder funds.
            </p>
          </div>
        </div>
      )}
    </Card>
  );
}
