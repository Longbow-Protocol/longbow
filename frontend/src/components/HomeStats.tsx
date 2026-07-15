"use client";

import { useProtocol } from "@/hooks/useProtocol";
import { fmt, fmtPrice } from "@/lib/format";

/**
 * Compact, live protocol stats for the homepage hero — read straight from the
 * chain via RPC (price from the oracle, supply from the LONG token, rewards
 * earmarked to open longs from the PositionManager).
 */
export function HomeStats() {
  const p = useProtocol();

  const items = [
    {
      tag: "PRICE",
      label: "LONG / ETH",
      value: fmtPrice(p.priceWad),
      unit: "ETH",
      accent: true,
    },
    {
      tag: "MARKET CAP",
      label: "Supply × price",
      value: fmt(p.marketCapWad, 2),
      unit: "ETH",
    },
    {
      tag: "LONG REWARDS",
      label: "Earmarked to open longs",
      value: fmt(p.totalEarmarked, 0),
      unit: "LONG",
    },
  ];

  return (
    <div className="grid max-w-2xl grid-cols-1 border border-[var(--color-border)] bg-[var(--color-panel)] sm:grid-cols-3">
      {items.map((it, i) => (
        <div
          key={it.tag}
          className={`px-4 py-4 ${
            i !== 0 ? "border-t border-[var(--color-border)] sm:border-t-0 sm:border-l" : ""
          }`}
        >
          <div className="label text-[var(--color-long)]">[ {it.tag} ]</div>
          <div
            className={`mt-2 text-2xl font-bold tracking-tight ${
              it.accent ? "text-[var(--color-long)]" : ""
            }`}
          >
            {p.configured ? (
              p.isLoading && p.priceWad === undefined ? (
                <span className="opacity-30">···</span>
              ) : (
                <>
                  {it.value}
                  <span className="ml-1.5 text-sm font-normal text-[var(--color-muted)]">
                    {it.unit}
                  </span>
                </>
              )
            ) : (
              <span className="text-[var(--color-muted)]">–</span>
            )}
          </div>
          <div className="label mt-1 tracking-normal normal-case">{it.label}</div>
        </div>
      ))}
    </div>
  );
}
