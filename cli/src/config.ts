import "dotenv/config";
import { defineChain, type Address } from "viem";

const ZERO = "0x0000000000000000000000000000000000000000" as const;

/** Robinhood Chain mainnet (4663) — env vars override when set. */
const MAINNET = {
  positionManager: "0x326B88686F1c3d875e8aCC5A841658561c6baA65",
  long: "0x3F29C51aAE41De14e062A8aA129cB928d277d58e",
  oracle: "0x95022e077CF330231C559AdbB0c9a2d5DC11283d",
} as const;

function envAddress(v: string | undefined, fallback: Address): Address {
  if (v && /^0x[0-9a-fA-F]{40}$/.test(v)) return v as Address;
  return fallback;
}

export const RPC_URL =
  process.env.LONGBOW_RPC_URL ?? "https://rpc.mainnet.chain.robinhood.com";

export const addresses = {
  positionManager: envAddress(
    process.env.LONGBOW_POSITION_MANAGER,
    MAINNET.positionManager,
  ),
  long: envAddress(process.env.LONGBOW_LONG_TOKEN, MAINNET.long),
  oracle: envAddress(process.env.LONGBOW_ORACLE, MAINNET.oracle),
} as const;

export function isConfigured(a: Address): boolean {
  return a !== ZERO;
}

export const contractsReady =
  isConfigured(addresses.positionManager) &&
  isConfigured(addresses.long) &&
  isConfigured(addresses.oracle);

/** Robinhood Chain — Arbitrum Orbit L2, ETH gas, chain id 4663. */
export const robinhoodChain = defineChain({
  id: 4663,
  name: "Robinhood Chain",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: { default: { http: [RPC_URL] } },
  blockExplorers: {
    default: { name: "Blockscout", url: "https://robinhoodchain.blockscout.com" },
  },
});

export const EXPLORER = "https://robinhoodchain.blockscout.com";
