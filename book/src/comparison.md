# Comparison

Same orders, different outcomes:

```mermaid
graph TB
    subgraph Input
        O["Orders:<br/>Alice buy@2, Alice buy@1<br/>Bob sell@2, Bob sell@1"]
    end

    O --> CLOB
    O --> DCLOB
    O --> Batch
    O --> ZK
    O --> SD
    O --> AMM

    subgraph CLOB["CentralizedCLOB"]
        direction TB
        C1["Trade 1: price = 2<br/>(Alice buy@2 vs Bob sell@2)"]
        C2["Trade 2: price = 1<br/>(Alice buy@1 vs Bob sell@1)"]
        C1 --> CS["Two different prices<br/>Spread arbitrage possible"]
    end

    subgraph DCLOB["DecentralizedCLOB"]
        direction TB
        DN1["Node 1: trade at price 2<br/>(saw sell@2 first)"]
        DN2["Node 2: trade at price 1<br/>(saw sell@1 first)"]
        DN1 --> DS["Nodes disagree on price<br/>Requires consensus"]
    end

    subgraph Batch["BatchedAuction"]
        direction TB
        B1["Clearing price = 1<br/>(maximizes volume)"]
        B2["All trades at price = 1"]
        B1 --> BS["One uniform price<br/>No spread arbitrage"]
    end

    subgraph ZK["ZKDarkPool"]
        direction TB
        ZK1["Sealed bids (hidden)"]
        ZK2["Clearing price = 1<br/>(same as BatchedAuction)"]
        ZK1 --> ZK2
        ZK2 --> ZKS["Uniform price + privacy<br/>Orders destroyed after clearing<br/>Sandwich impossible"]
    end

    subgraph SD["ShieldedDEX"]
        direction TB
        SD1["Pair hidden + sealed bids"]
        SD2["Per-pair clearing<br/>(P1@1, P2@2)"]
        SD1 --> SD2
        SD2 --> SDS["Asset-type privacy<br/>Cross-pair arbitrage impossible<br/>Price discovery lost"]
    end

    subgraph AMM["AMM"]
        direction TB
        A1["Swap 1: 2A in, 1B out<br/>(effective price: 2)"]
        A2["Swap 2: 3A in, 1B out<br/>(effective price: 3)"]
        A1 --> AS["Price impact per swap<br/>Larger swaps get worse rates"]
    end

    style CS fill:#fee
    style DS fill:#fdd
    style BS fill:#efe
    style ZKS fill:#dfd
    style SDS fill:#cfc
    style AS fill:#fee
```

## Structural differences (TLC-verified)

| Property | CentralizedCLOB | DecentralizedCLOB | BatchedAuction | ZKDarkPool | ShieldedDEX | AMM |
|---|---|---|---|---|---|---|
| Uniform pricing | No | No | Yes (verified) | Yes (verified) | Yes (per-pair, verified) | No |
| Ordering independence | No (price-time priority) | No (delivery order) | Yes (verified) | Yes (verified) | Yes (per-pair, verified) | No (price impact) |
| Cross-node consensus | N/A (single node) | No (TLC counterexample) | Yes (ordering independence) | Yes (ordering independence) | Yes (per-pair) | N/A (single pool) |
| Spread arbitrage possible | Yes | Yes | No (uniform price) | No (uniform price) | No (per-pair uniform price) | Yes (price impact) |
| Front-running resistant | No (TLC counterexample) | No (ordering power) | Yes (ordering independence) | Yes (ordering independence) | Yes (pair hidden + ordering independence) | N/A (no order book) |
| Wash trading resistant | Yes (self-trade prevention) | Yes (self-trade prevention) | Yes (self-trade prevention) | Yes (self-trade prevention) | Yes (self-trade prevention) | No (no identity check) |
| Sandwich attack resistant | Trust assumption (single operator) | No (ordering power) | Yes (uniform price) | Yes (verified: SandwichResistant) | Yes (verified: per-pair + pair hidden) | No (TLC counterexample) |
| Pre-trade privacy | No | No | No | Yes (sealed bids) | Yes (sealed bids + pair hidden) | No |
| Post-trade privacy | No | No | No | Yes (verified: orders destroyed) | Yes (verified: all pairs destroyed) | No |
| Asset-type privacy | No | No | No | No (pair known) | Yes (pair hidden in commitment) | No |
| Cross-pair arbitrage | N/A | N/A | N/A | N/A | Impossible (pair hidden) | N/A |
| Always-available liquidity | No (book can be empty) | No (book can be empty) | No (batch can be empty) | No (batch can be empty) | No (batch can be empty) | Yes (verified) |
| Price improvement | Yes (verified) | Yes (per-node, verified) | Yes (verified) | Yes (verified) | Yes (per-pair, verified) | N/A (no limit prices) |
| Cross-venue arbitrage | Source venue | Source venue | Resistant (uniform price) | Resistant (uniform price + privacy) | Resistant (uniform price + full privacy) | Target venue (LP bears cost) |
| LP impermanent loss | N/A | N/A | N/A | N/A | N/A | Yes (TLC counterexample) |
| Constant product (k) | N/A | N/A | N/A | N/A | N/A | Yes (verified) |
| Conservation | Yes (verified) | Yes (per-node) | Yes (verified) | Yes (verified) | Yes (per-pair, verified) | Yes (verified) |

## Counterexamples

To see counterexamples, add these invariants to the respective `.cfg` files:

- **CLOB non-uniform pricing**: add `INVARIANT AllTradesSamePrice` to `CentralizedCLOB.cfg` (with `MaxTime = 4`, `MaxOrders = 4`)
- **AMM non-uniform pricing**: add `INVARIANT AllSwapsSamePrice` to `AMM.cfg` (with `MaxTime = 4`)
- **Decentralized CLOB divergence**: add `INVARIANT ConsensusOnTrades` (or `ConsensusOnPrices`, `ConsensusOnVolume`) to `DecentralizedCLOB.cfg`
- **Latency arbitrage**: add `INVARIANT NoArbitrageProfit` or `INVARIANT MarketMakerNotHarmed` to `LatencyArbitrage.cfg`
- **CLOB front-running**: add `INVARIANT NoPriceDegradation` or `INVARIANT NoAdversaryProfit` to `FrontRunning.cfg`
- **Wash trading**: add `INVARIANT NoWashTrading`, `INVARIANT NoManipulatorLoss`, or `INVARIANT VolumeReflectsActivity` to `WashTrading.cfg`
- **Sandwich attack**: add `INVARIANT NoPriceDegradation` or `INVARIANT NoAdversaryProfit` to `SandwichAttack.cfg`
- **Impermanent loss**: add `INVARIANT NoImpermanentLoss` to `ImpermanentLoss.cfg`
- **Cross-venue arbitrage profit**: add `INVARIANT NoArbitrageProfit` or `INVARIANT NoLPValueLoss` to `CrossVenueArbitrage.cfg`
- **Cross-pair price divergence**: add `INVARIANT CrossPairPriceConsistency` to `ShieldedDEX.cfg`
