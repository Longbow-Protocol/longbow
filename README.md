<div align="center">

# Longbow

**The leverage layer for `$LONG` on Robinhood Chain.**

Deposit ETH, pick a multiplier, and earn `$LONG` as the price climbs.
No shorts. No borrowing. No tokens up front.

[Website](https://longbow-protocol.xyz) · [Dashboard](https://longbow-protocol.xyz/dashboard) · [Litepaper](https://longbow-protocol.xyz/litepaper) · [Explorer](https://robinhoodchain.blockscout.com)

</div>

---

## What is Longbow?

Longbow is a self-custodial protocol on **Robinhood Chain** (an Arbitrum Orbit L2, chain id `4663`).
Instead of buying the token, you **open a long**: deposit ETH as collateral, choose a
multiplier, and accrue `$LONG` reward tokens from a finite, pre-funded reserve as the price
rises. Exit any time to reclaim your equity plus rewards — or get liquidated if you fall too
far, in which case your collateral is donated to the liquidity pool forever.

- **No tokens up front.** Your ETH is held as collateral; rewards are earmarked at open, so the protocol is always solvent.
- **No shorts, no borrowing, no interest.** The only way is long.
- **Losses feed liquidity.** Liquidated collateral and underwater shortfalls are added to the `$LONG` pool permanently.

### How a position works

```
maxReward   = collateral × multiplier / P0          (earmarked at open)
reward(P)   = maxReward × (P − P0) / P               (0 at entry, → maxReward as price grows)
```

1. **Deposit ETH** — held as collateral, never lent out while healthy.
2. **Pick a multiplier** — higher leverage earns faster, but moves your liquidation price closer to entry.
3. **Earn as it climbs** — reward `$LONG` accrues from the reserve as price rises.
4. **Exit anytime** — reclaim equity in ETH plus your reward tokens.
5. **Liquidation** — fall to the maintenance margin and anyone can liquidate you for a bounty; the rest of your collateral joins the pool.

Full mechanism, worked examples, and architecture are in the [litepaper](https://longbow-protocol.xyz/litepaper).

## Repository layout

This is a monorepo:

| Path | What |
| --- | --- |
| [`src/`](src) | Solidity contracts — `LongToken`, `PositionManager`, TWAP oracle, liquidity sink |
| [`script/`](script) | Foundry deployment scripts |
| [`test/`](test) | Foundry unit, invariant, and fork tests |
| [`frontend/`](frontend) | Next.js website, dashboard, and litepaper |
| [`cli/`](cli) | Self-custodial terminal client ([`longbow-cli`](cli/README.md)) |
| [`keeper/`](keeper) | Off-chain liquidation keeper bot |

> The Solidity core also has its own standalone home at
> **[Longbow-Protocol/contracts](https://github.com/Longbow-Protocol/contracts)** — the canonical,
> audit-friendly contracts repo. The `src/`, `test/`, and `script/` here are kept in sync with it.

## Quickstart (CLI)

If you have [Node.js](https://nodejs.org) 18+:

```bash
npx longbow-cli
```

Or download a standalone binary (no Node needed) from [Releases](https://github.com/Longbow-Protocol/longbow/releases).
Your private key never leaves your machine — the CLI signs locally. See [`cli/README.md`](cli/README.md).

## Development

### Contracts (Foundry)

```bash
forge install      # pull submodules (forge-std, openzeppelin-contracts)
forge build
forge test
forge script script/Deploy.s.sol --rpc-url <rpc> --private-key <key> --broadcast
```

### Frontend (Next.js)

```bash
cd frontend
npm install
cp .env.local.example .env.local   # fill in deployed contract addresses
npm run dev                         # http://localhost:3000
```

### CLI (from source)

```bash
cd cli
npm install
npm start                           # interactive menu
```

> Clone with `git clone --recurse-submodules` if you plan to build the contracts.

## Security

Longbow is non-custodial. There is no backend and no server in the signing path — the web app
signs in your wallet, and the CLI signs locally with a key that stays in memory for the session
and is never stored or transmitted.

## Disclaimer

Longbow is an experiment, released as-is. Smart contracts are unaudited. Leverage can result in
the total loss of your collateral through liquidation. Nothing here is financial advice. Do your
own research and never deposit more than you can afford to lose.

## License

MIT.
