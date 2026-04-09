# Shared Definitions

[`Common.tla`](https://github.com/oxarbitrage/formal-market-mechanisms/blob/main/specs/Common.tla) contains reusable definitions across all mechanisms:

- Order tuple accessors: `OTrader`, `OPrice`, `OQty`, `OId`, `OTime`
- Trade tuple accessors: `TBuyer`, `TSeller`, `TPrice`, `TQty`, `TTime`, `TBuyLimit`, `TSellLimit`
- Sequence helpers: `RemoveAt`, `ReplaceAt`
- Arithmetic helpers: `Min`, `Max`

## Terminology

| Term | Definition |
|---|---|
| **AMM** | Automated Market Maker — a pool-based exchange where price is determined by a mathematical formula (e.g., constant-product `x*y=k`) rather than an order book |
| **CLOB** | Central Limit Order Book — a price-time priority matching engine where resting orders are matched against incoming orders |
| **DEX** | Decentralized Exchange — a non-custodial trading venue running on a blockchain or peer-to-peer protocol |
| **HFT** | High-Frequency Trading — automated trading at microsecond timescales, often exploiting latency advantages |
| **IL** | Impermanent Loss — the difference between the value of tokens held in an AMM LP position vs. simply holding them; disappears if the price ratio returns to the deposit ratio |
| **LP** | Liquidity Provider — a participant who deposits tokens into an AMM pool and earns fees in return, bearing IL risk |
| **MEV** | Maximal (formerly Miner) Extractable Value — value extracted by controlling transaction ordering, e.g., front-running or sandwich attacks |
| **MPC** | Multi-Party Computation — cryptographic protocol where multiple parties jointly compute a function without revealing their private inputs |
| **ZK / ZKP** | Zero-Knowledge Proof — a cryptographic proof that a statement is true without revealing why it is true (e.g., an order is valid without revealing the order) |
