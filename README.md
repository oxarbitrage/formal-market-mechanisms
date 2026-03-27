# Formal Market Mechanisms

TLA+ specifications for comparing market mechanisms. The goal is to formally verify correctness properties and compare structural differences across centralized, decentralized, continuous, and batched trading systems.

## Mechanisms

### CentralizedCLOB

A continuous limit order book with a single matching engine. Orders are matched immediately using price-time priority.

```mermaid
graph LR
    subgraph Order Book
        BB[Buy Book<br/>sorted by price desc]
        SB[Sell Book<br/>sorted by price asc]
    end

    O1[Submit Buy] --> BB
    O2[Submit Sell] --> SB

    BB -- "best bid >= best ask" --> ME{Match Engine}
    SB -- "best bid >= best ask" --> ME

    ME -- "fill at ask price" --> T[Trade]
    ME -- "partial fill" --> BB
    ME -- "partial fill" --> SB
```

Each order is matched **immediately** on arrival. The trade executes at the resting order's price. Different trades can execute at different prices (enabling spread arbitrage).

- **Matching**: best bid vs best ask, executes at the ask (resting order) price
- **Partial fills**: smaller side is fully filled, larger side's quantity is reduced
- **Self-trade prevention**: a trader cannot match against themselves

**Verified properties:**
| Property | Type | Description |
|---|---|---|
| PositiveBookQuantities | Invariant | Every resting order has quantity > 0 |
| PositiveTradeQuantities | Invariant | Every trade has quantity > 0 |
| PriceImprovement | Invariant | Trade price <= buyer's limit and >= seller's limit |
| NoSelfTrades | Invariant | No trade has the same buyer and seller |
| UniqueOrderIds | Invariant | All order IDs on the books are distinct |
| ConservationOfAssets | Invariant | Trade log is consistent across traders |
| EventualMatching | Liveness | Crossed books between different traders are eventually resolved |

### BatchedAuction

A periodic auction that collects orders over a batch window, then clears all at a single uniform price that maximizes traded volume.

```mermaid
graph LR
    subgraph Collecting
        BO[Buy Orders]
        SO[Sell Orders]
    end

    O1[Submit Buy] --> BO
    O2[Submit Sell] --> SO

    BO --> CB[Close Batch]
    SO --> CB

    subgraph Clearing
        CB --> D[Demand Curve]
        CB --> S[Supply Curve]
        D --> CP[Clearing Price<br/>max volume]
        S --> CP
    end

    CP -- "all at uniform price" --> T[Trades]
    T --> R[Reset]
    R -. "next batch" .-> BO
```

Orders accumulate during the **collection phase** without matching. When the batch closes, a single **clearing price** is computed that maximizes traded volume. All trades execute at this uniform price — no spread to capture.

- **Collection phase**: orders accumulate without matching
- **Clearing phase**: compute clearing price from aggregate supply/demand curves, fill eligible orders at the uniform price
- **Self-trade prevention**: buyer-seller pairs with the same trader are skipped during clearing

**Verified properties:**
| Property | Type | Description |
|---|---|---|
| UniformClearingPrice | Invariant | All trades in a batch execute at the same price |
| PriceImprovement | Invariant | Trade price <= buyer's limit and >= seller's limit |
| PositiveTradeQuantities | Invariant | Every trade has quantity > 0 |
| NoSelfTrades | Invariant | No trade has the same buyer and seller |
| OrderingIndependence | Invariant | Clearing result matches the deterministic clearing price regardless of submission order |
| NoSpreadArbitrage | Invariant | No price difference to exploit within a batch |
| EventualClearing | Liveness | Every batch eventually clears |

## Comparison

Same orders, different outcomes:

```mermaid
graph TB
    subgraph Input
        O["Orders:<br/>Alice buy@2, Alice buy@1<br/>Bob sell@2, Bob sell@1"]
    end

    O --> CLOB
    O --> Batch

    subgraph CLOB["CentralizedCLOB"]
        direction TB
        C1["Trade 1: price = 2<br/>(Alice buy@2 vs Bob sell@2)"]
        C2["Trade 2: price = 1<br/>(Alice buy@1 vs Bob sell@1)"]
        C1 --> CS["Two different prices<br/>Spread arbitrage possible"]
    end

    subgraph Batch["BatchedAuction"]
        direction TB
        B1["Clearing price = 1<br/>(maximizes volume)"]
        B2["All trades at price = 1"]
        B1 --> BS["One uniform price<br/>No spread arbitrage"]
    end

    style CS fill:#fee
    style BS fill:#efe
```

The key structural difference, verified by TLC:

| Property | CentralizedCLOB | BatchedAuction |
|---|---|---|
| Uniform pricing | No (TLC finds counterexample) | Yes (verified) |
| Ordering independence | No (price-time priority) | Yes (verified) |
| Spread arbitrage possible | Yes (different trade prices) | No (uniform price) |
| Price improvement | Yes (verified) | Yes (verified) |
| Self-trade prevention | Yes (verified) | Yes (verified) |

To see the CLOB counterexample: add `INVARIANT AllTradesSamePrice` to `CentralizedCLOB.cfg` (with `MaxTime = 4`, `MaxOrders = 4`). TLC will produce a trace with two trades at different prices.

## Shared

`Common.tla` contains reusable definitions across all mechanisms:
- Order tuple accessors: `OTrader`, `OPrice`, `OQty`, `OId`, `OTime`
- Trade tuple accessors: `TBuyer`, `TSeller`, `TPrice`, `TQty`, `TTime`, `TBuyLimit`, `TSellLimit`
- Sequence helpers: `RemoveAt`, `ReplaceAt`
- Arithmetic helpers: `Min`, `Max`

## Running

Requires Java and [tla2tools.jar](https://github.com/tlaplus/tlaplus/releases). From the `specs/` directory:

```bash
java -DTLC -cp /path/to/tla2tools.jar tlc2.TLC CentralizedCLOB -config CentralizedCLOB.cfg -modelcheck
java -DTLC -cp /path/to/tla2tools.jar tlc2.TLC BatchedAuction -config BatchedAuction.cfg -modelcheck
```

Or use the [TLA+ VS Code extension](https://marketplace.visualstudio.com/items?itemName=tlaplus.vscode-tlaplus).

## Planned

- **AMM (Automated Market Maker)** - constant-product (x*y=k) model, sandwich attack traces
- **Decentralized CLOB** - multiple nodes, ordering ambiguity, consensus
- **ZK Dark Pool** - verifiable private matching, encrypted order visibility
- Privacy/visibility model across all mechanisms
- Adversarial conditions and manipulation resistance analysis
