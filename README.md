# Formal Market Mechanisms

TLA+ specifications that formally verify and compare market mechanisms — CLOBs, batch auctions, AMMs, and privacy-preserving dark pools — across correctness, fairness, MEV resistance, and decentralizability.

**[Read the full book](book/src/SUMMARY.md)**

## Key results (all TLC-verified, not just argued)

- An **impossibility triangle** between fairness, liquidity, and immediacy — no mechanism can provide all three
- Batch auctions are **safe to decentralize** (OrderingIndependence); CLOBs are not (TLC counterexample: same orders → different trades at different nodes)
- Sandwich attacks, front-running, and latency arbitrage are **structurally impossible** in batch auctions — formally verified, not just claimed
- Privacy (sealed bids + order destruction) is a **mechanism design tool** for MEV elimination, proven equivalent to batch clearing via refinement mapping
- Asset-type privacy (ShieldedDEX) adds a **4th dimension** to the impossibility triangle — privacy vs price discovery — but does NOT fix the original three-way tradeoff
- AMMs provide **always-available liquidity** but are vulnerable to sandwich attacks, wash trading, and impermanent loss — all with TLC counterexamples
- **ShieldedDEX** is the only mechanism to resist all 6 attack categories (6/6) — combining the strongest privacy with the least vulnerable clearing mechanism

## Specs

### Mechanisms

| Spec | Description |
|---|---|
| [CentralizedCLOB](specs/CentralizedCLOB.tla) | Continuous limit order book with price-time priority matching |
| [BatchedAuction](specs/BatchedAuction.tla) | Periodic auction clearing at uniform price that maximizes volume |
| [AMM](specs/AMM.tla) | Constant-product market maker (x*y=k) |
| [ZKDarkPool](specs/ZKDarkPool.tla) | Sealed-bid batch auction with commit-reveal protocol |
| [ShieldedDEX](specs/ShieldedDEX.tla) | Multi-asset shielded exchange — asset pair hidden in commitment (novel) |
| [DecentralizedCLOB](specs/DecentralizedCLOB.tla) | Multi-node CLOB with nondeterministic order delivery |

### Attacks & Economic Properties

| Spec | Description |
|---|---|
| [SandwichAttack](specs/SandwichAttack.tla) | AMM sandwich attack (front-run + back-run) |
| [FrontRunning](specs/FrontRunning.tla) | CLOB front-running via liquidity depletion |
| [LatencyArbitrage](specs/LatencyArbitrage.tla) | Cross-exchange stale quote sniping (Budish et al. 2015) |
| [WashTrading](specs/WashTrading.tla) | AMM volume inflation via self-trading round-trips |
| [ImpermanentLoss](specs/ImpermanentLoss.tla) | LP economic risk from price movement |
| [CrossVenueArbitrage](specs/CrossVenueArbitrage.tla) | CLOB-AMM price convergence arbitrage |

### Proofs

| Spec | Description |
|---|---|
| [ZKRefinement](specs/ZKRefinement.tla) | Formal proof: ZKDarkPool implements BatchedAuction |

### Shared

| Spec | Description |
|---|---|
| [Common](specs/Common.tla) | Order/trade accessors, sequence helpers, arithmetic utilities |

## Vulnerability resistance (TLC-verified)

| Attack | CLOB | Decentralized CLOB | Batch Auction | ZKDarkPool | ShieldedDEX | AMM |
|---|---|---|---|---|---|---|
| Front-running | Vulnerable | Vulnerable | **Resistant** | **Resistant** | **Resistant** | N/A |
| Sandwich | Trust assumption | Vulnerable | **Resistant** | **Resistant** | **Resistant** | Vulnerable |
| Latency arbitrage | Vulnerable | Vulnerable | **Resistant** | **Resistant** | **Resistant** | N/A |
| Wash trading | Resistant | Resistant | Resistant | Resistant | Resistant | Vulnerable |
| Spread arbitrage | Vulnerable | Vulnerable | **Resistant** | **Resistant** | **Resistant** | Vulnerable |
| Asset-targeted | Vulnerable | Vulnerable | Vulnerable | Vulnerable | **Resistant** | Vulnerable |
| **Score** | **1/6** | **1/6** | **5/6** | **5/6** | **6/6** | **1/6** |

## Running

Requires Java and [tla2tools.jar](https://github.com/tlaplus/tlaplus/releases). From the `specs/` directory:

```bash
java -DTLC -cp /path/to/tla2tools.jar tlc2.TLC <Module> -config <Module>.cfg -modelcheck
```

See [Running the Specs](book/src/running.md) for the full list of commands, or use the [TLA+ VS Code extension](https://marketplace.visualstudio.com/items?itemName=tlaplus.vscode-tlaplus).

## References

| Mechanism | Real-world systems |
|---|---|
| CentralizedCLOB | NYSE, NASDAQ, CME, Binance, Coinbase |
| BatchedAuction | [Penumbra](https://penumbra.zone/), [CoW Protocol](https://cow.fi/), NYSE/NASDAQ opening & closing auctions |
| AMM | [Uniswap v2](https://docs.uniswap.org/contracts/v2/overview), SushiSwap, PancakeSwap, [Curve](https://curve.fi/), [Balancer](https://balancer.fi/) |
| ZKDarkPool | [Penumbra](https://penumbra.zone/), [Renegade](https://renegade.fi/), [MEV Blocker](https://mevblocker.io/) |
| ShieldedDEX | [Zcash ZSA (ZIP-226/227)](https://zips.z.cash/zip-0226), [Penumbra](https://penumbra.zone/), [Anoma](https://anoma.net/) |
| DecentralizedCLOB | [Serum/OpenBook](https://www.openbook-solana.com/), [dYdX v4](https://dydx.exchange/), [Hyperliquid](https://hyperliquid.xyz/) |

**Academic:** Budish, Cramton, Shim — "[The High-Frequency Trading Arms Race](https://faculty.chicagobooth.edu/eric.budish/research/HFT-FrequentBatchAuctions.pdf)" (2015)
