import Link from "next/link";
import type { Metadata } from "next";
import { Header } from "@/components/Header";
import { Footer } from "@/components/Footer";
import { AddressPill } from "@/components/AddressPill";
import { addresses } from "@/lib/contracts";
import {
  ABSENT,
  FULL_SOURCE,
  GUARANTEES,
  LP_LOCK_META,
  SURFACE,
} from "@/content/lpLock";

export const metadata: Metadata = {
  title: "The LP Lock",
  description:
    "Longbow’s Uniswap V3 LP locker — permanent liquidity, owner-only fee claims, no unlock path.",
};

export default function LpLockPage() {
  return (
    <main className="min-h-screen pb-24">
      <Header />

      <div className="mx-auto max-w-6xl px-5">
        <section className="border-b border-[var(--color-border)] py-14 md:py-20">
          <div className="eyebrow">{LP_LOCK_META.eyebrow}</div>
          <h1 className="display mt-4 text-5xl md:text-6xl">
            THE LP <span className="text-[var(--color-long)]">LOCK</span>
          </h1>
          <p className="mt-5 max-w-2xl text-[var(--color-muted)]">{LP_LOCK_META.intro}</p>

          <div className="mt-8 flex flex-wrap items-center gap-3">
            <AddressPill label="LP LOCKER" address={addresses.lpLocker} />
          </div>

          <div className="label mt-6 flex flex-wrap gap-x-6 gap-y-2">
            <span>CONTRACT · UniswapV3LpLocker</span>
            <span>CHAIN · ROBINHOOD 4663</span>
            <span>
              OWNER · {LP_LOCK_META.owner.slice(0, 6)}…{LP_LOCK_META.owner.slice(-4)}
            </span>
          </div>

          <div className="mt-8 flex flex-wrap gap-3">
            <a
              href={LP_LOCK_META.github}
              target="_blank"
              rel="noreferrer"
              className="btn flex items-center gap-2 px-5 py-3"
            >
              VIEW SOURCE ON GITHUB <span>{"\u2192"}</span>
            </a>
            <Link href="/#how" className="btn flex items-center gap-2 px-5 py-3">
              HOW LONGBOW WORKS
            </Link>
          </div>
        </section>

        {/* Guarantees */}
        <section className="py-14">
          <div className="mb-8 flex items-end justify-between gap-4">
            <div>
              <div className="eyebrow">[ WHY IT&apos;S SAFE ]</div>
              <h2 className="display mt-3 text-3xl md:text-4xl">Small surface. Hard guarantees.</h2>
            </div>
            <span className="label hidden md:block">4 PROPERTIES</span>
          </div>

          <div className="grid border border-[var(--color-border)] bg-[var(--color-panel)] md:grid-cols-2">
            {GUARANTEES.map((g, i) => (
              <div
                key={g.tag}
                className={`p-6 md:p-7 ${i % 2 === 1 ? "md:border-l md:border-[var(--color-border)]" : ""} ${
                  i >= 2 ? "border-t border-[var(--color-border)]" : ""
                }`}
              >
                <div className="eyebrow">[ {g.tag} ]</div>
                <h3 className="mt-3 text-lg font-bold tracking-tight">{g.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-[var(--color-muted)]">{g.body}</p>
              </div>
            ))}
          </div>
        </section>

        {/* Flow */}
        <section className="border-t border-[var(--color-border)] py-14">
          <div className="eyebrow">[ THE FLOW ]</div>
          <h2 className="display mt-3 text-3xl md:text-4xl">Lock once. Claim forever.</h2>

          <ol className="mt-8 grid gap-0 border border-[var(--color-border)] bg-[var(--color-panel)] md:grid-cols-3">
            {[
              {
                n: "01",
                title: "Mint LP",
                body: "Seed the LONG/WETH Uniswap V3 pool. You receive a position NFT.",
              },
              {
                n: "02",
                title: "burnLP",
                body: "Owner approves the locker and calls burnLP. The NFT moves in — permanently.",
              },
              {
                n: "03",
                title: "safeClaim",
                body: "Trading fees accrue on the position. Only the owner can collect them.",
              },
            ].map((step, i) => (
              <li
                key={step.n}
                className={`p-6 md:p-7 ${i > 0 ? "border-t border-[var(--color-border)] md:border-t-0 md:border-l" : ""}`}
              >
                <div className="mono text-sm text-[var(--color-long)]">{step.n}</div>
                <h3 className="mt-3 text-lg font-bold tracking-tight">{step.title}</h3>
                <p className="mt-2 text-sm text-[var(--color-muted)]">{step.body}</p>
              </li>
            ))}
          </ol>
        </section>

        {/* Function breakdown */}
        <section className="border-t border-[var(--color-border)] py-14">
          <div className="mb-8">
            <div className="eyebrow">[ SURFACE AREA ]</div>
            <h2 className="display mt-3 text-3xl md:text-4xl">Two functions. That&apos;s it.</h2>
            <p className="mt-3 max-w-2xl text-[var(--color-muted)]">
              The entire mutable API is owner-gated. Below is the real logic the locker exposes —
              nothing else can move the NFT or redirect fees.
            </p>
          </div>

          <div className="space-y-4">
            {SURFACE.map((fn) => (
              <article
                key={fn.name}
                className="border border-[var(--color-border)] bg-[var(--color-panel)]"
              >
                <div className="flex flex-wrap items-center justify-between gap-3 border-b border-[var(--color-border)] px-5 py-4">
                  <div>
                    <div className="mono text-sm text-[var(--color-long)]">{fn.sig}</div>
                    <p className="mt-1 text-sm text-[var(--color-muted)]">{fn.what}</p>
                  </div>
                  <span className="label border border-[var(--color-border-bright)] px-2 py-1 text-[var(--color-long)]">
                    ONLY {fn.who.toUpperCase()}
                  </span>
                </div>
                <pre className="overflow-x-auto bg-[var(--color-panel-2)] p-5 text-[13px] leading-relaxed text-[var(--color-fg)]">
                  <code className="mono">{fn.code}</code>
                </pre>
              </article>
            ))}
          </div>
        </section>

        {/* What's missing */}
        <section className="border-t border-[var(--color-border)] py-14">
          <div className="grid gap-8 lg:grid-cols-[1fr_1.2fr]">
            <div>
              <div className="eyebrow">[ WHAT ISN&apos;T THERE ]</div>
              <h2 className="display mt-3 text-3xl md:text-4xl">Absence is the feature.</h2>
              <p className="mt-4 text-[var(--color-muted)]">
                Safety here is mostly about what the contract cannot do. If a function that could
                unlock liquidity doesn&apos;t exist, it can&apos;t be called — by anyone, ever.
              </p>
            </div>
            <ul className="border border-[var(--color-border)] bg-[var(--color-panel)]">
              {ABSENT.map((item) => (
                <li
                  key={item}
                  className="flex items-start gap-3 border-b border-[var(--color-border)] px-5 py-4 last:border-b-0"
                >
                  <span className="mono mt-0.5 text-[var(--color-danger)]" aria-hidden>
                    ×
                  </span>
                  <span className="mono text-sm">{item}</span>
                </li>
              ))}
            </ul>
          </div>
        </section>

        {/* Full source */}
        <section className="border-t border-[var(--color-border)] py-14">
          <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
            <div>
              <div className="eyebrow">[ FULL SOURCE ]</div>
              <h2 className="display mt-3 text-3xl md:text-4xl">UniswapV3LpLocker.sol</h2>
            </div>
            <a
              href={LP_LOCK_META.github}
              target="_blank"
              rel="noreferrer"
              className="label hover:text-[var(--color-long)]"
            >
              GITHUB ↗
            </a>
          </div>
          <div className="framed border border-[var(--color-border)] bg-[var(--color-panel-2)]">
            <div className="flex items-center gap-2 border-b border-[var(--color-border)] px-4 py-2">
              <span className="h-2 w-2 bg-[var(--color-danger)]" />
              <span className="h-2 w-2 bg-[var(--color-warn)]" />
              <span className="h-2 w-2 bg-[var(--color-long)]" />
              <span className="label ml-2">src/periphery/UniswapV3LpLocker.sol</span>
            </div>
            <pre className="max-h-[36rem] overflow-auto p-5 text-[12px] leading-relaxed md:text-[13px]">
              <code className="mono text-[var(--color-fg)]">{FULL_SOURCE}</code>
            </pre>
          </div>
        </section>

        <section className="border border-[var(--color-border)] bg-[var(--color-panel)] p-8 md:p-10">
          <div className="eyebrow">[ NEXT ]</div>
          <h2 className="display mt-3 text-2xl md:text-3xl">Liquidity that can&apos;t walk away.</h2>
          <p className="mt-3 max-w-xl text-[var(--color-muted)]">
            When the locker is deployed and the seed NFT is burned in, this page will point at the
            live address. Until then the placeholder above is ready to copy — swap it the moment
            we go live.
          </p>
          <div className="mt-6 flex flex-wrap gap-3">
            <Link href="/dashboard" className="btn btn-primary flex items-center gap-2 px-5 py-3">
              OPEN DASHBOARD <span>{"\u2192"}</span>
            </Link>
            <Link href="/litepaper" className="btn flex items-center gap-2 px-5 py-3">
              READ THE LITEPAPER
            </Link>
          </div>
        </section>
      </div>

      <Footer />
    </main>
  );
}
