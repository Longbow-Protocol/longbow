"use client";

import { useReadContracts } from "wagmi";
import { addresses, erc20Abi, isConfigured, oracleAbi, positionManagerAbi } from "@/lib/contracts";

const WAD = 10n ** 18n;

export type Protocol = {
  priceWad?: bigint;
  maxMultiplierWad?: bigint;
  minCollateral?: bigint;
  maintenanceMarginBps?: bigint;
  reserveBalance?: bigint;
  availableReserve?: bigint;
  totalEarmarked?: bigint;
  nextPositionId?: bigint;
  tokenSupply?: bigint;
  /** Fully-diluted market cap in ETH (WAD): totalSupply × price. */
  marketCapWad?: bigint;
  isLoading: boolean;
  configured: boolean;
};

export function useProtocol(): Protocol {
  const pm = addresses.positionManager;
  const oracle = addresses.oracle;
  const long = addresses.long;
  const configured = isConfigured(pm) && isConfigured(oracle);

  const { data, isLoading } = useReadContracts({
    query: { enabled: configured },
    contracts: [
      { address: oracle, abi: oracleAbi, functionName: "priceWad" },
      { address: pm, abi: positionManagerAbi, functionName: "maxMultiplierWad" },
      { address: pm, abi: positionManagerAbi, functionName: "minCollateral" },
      { address: pm, abi: positionManagerAbi, functionName: "maintenanceMarginBps" },
      { address: pm, abi: positionManagerAbi, functionName: "reserveBalance" },
      { address: pm, abi: positionManagerAbi, functionName: "availableReserve" },
      { address: pm, abi: positionManagerAbi, functionName: "totalEarmarked" },
      { address: pm, abi: positionManagerAbi, functionName: "nextPositionId" },
      { address: long, abi: erc20Abi, functionName: "totalSupply" },
    ],
  });

  const val = (i: number) =>
    data?.[i]?.status === "success" ? (data[i].result as bigint) : undefined;

  const priceWad = val(0);
  const tokenSupply = val(8);
  const marketCapWad =
    priceWad !== undefined && tokenSupply !== undefined
      ? (tokenSupply * priceWad) / WAD
      : undefined;

  return {
    priceWad,
    maxMultiplierWad: val(1),
    minCollateral: val(2),
    maintenanceMarginBps: val(3),
    reserveBalance: val(4),
    availableReserve: val(5),
    totalEarmarked: val(6),
    nextPositionId: val(7),
    tokenSupply,
    marketCapWad,
    isLoading,
    configured,
  };
}
