"use client";

import { useState } from "react";
import type { Address } from "viem";
import { isConfigured } from "@/lib/contracts";
import { shortAddress } from "@/lib/format";
import { robinhoodChain } from "@/lib/chain";

type Props = {
  label: string;
  address: Address;
  pendingLabel?: string;
};

export function AddressPill({ label, address, pendingLabel = "PENDING DEPLOYMENT" }: Props) {
  const configured = isConfigured(address);
  const [copied, setCopied] = useState(false);
  const explorer = robinhoodChain.blockExplorers?.default.url;

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(address);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      /* clipboard unavailable */
    }
  };

  return (
    <div className="inline-flex max-w-full flex-wrap items-stretch border border-[var(--color-border)] bg-[var(--color-panel)]">
      <div className="flex min-w-0 items-center gap-2.5 px-3 py-2">
        <span className="label flex-none">{label}</span>
        {configured ? (
          <a
            href={`${explorer}/address/${address}`}
            target="_blank"
            rel="noreferrer"
            className="mono truncate text-sm transition hover:text-[var(--color-long)]"
            title="Open in explorer"
          >
            <span className="hidden sm:inline">{address}</span>
            <span className="sm:hidden">{shortAddress(address)}</span>
          </a>
        ) : (
          <span className="mono truncate text-sm text-[var(--color-muted)]" title={address}>
            <span className="hidden sm:inline">{address}</span>
            <span className="sm:hidden">{shortAddress(address)}</span>
            <span className="ml-2 text-[var(--color-warn)]">{pendingLabel}</span>
          </span>
        )}
      </div>
      <button
        onClick={copy}
        aria-label="Copy address"
        title="Copy address"
        className="flex flex-none items-center gap-1.5 border-l border-[var(--color-border)] px-3 text-[var(--color-muted)] transition hover:text-[var(--color-long)]"
      >
        {copied ? <CheckIcon /> : <CopyIcon />}
        <span className="label">{copied ? "COPIED" : "COPY"}</span>
      </button>
    </div>
  );
}

function CopyIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <rect x="9" y="9" width="11" height="11" />
      <path d="M5 15H4a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v1" />
    </svg>
  );
}

function CheckIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" aria-hidden>
      <path d="M20 6 9 17l-5-5" />
    </svg>
  );
}
