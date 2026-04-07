# Formal Market Mechanisms

A collection of TLA+ specifications that formally verify and compare market mechanisms (CLOBs, batch auctions, AMMs, and privacy-preserving dark pools) across correctness, fairness, MEV resistance, and decentralizability.


```mermaid
graph LR
    CLOB[CentralizedCLOB<br/><font size = '-1'>immediacy</font>] --> DCLOB[DecentralizedCLOB<br/><font size = '-1'>multi-node</font>]
    BA[BatchedAuction<br/><font size = '-1'>fairness</font>] -->|sealed bids| ZK[ZKDarkPool<br/><font size = '-1'>privacy</font>]
    ZK -->|pair hiding| SDEX[ShieldedDEX<br/><font size = '-1'>full privacy</font>]
    BA -.->|refinement proof| ZK
    AS[ShieldedAtomicSwap<br/><font size = '-1'>P2P settlement<br/>cross-chain native</font>]
    AMM[AMM<br/><font size = '-1'>always-on liquidity<br/>comparison baseline</font>]
```

**7 mechanism specs:** CentralizedCLOB · BatchedAuction · AMM · ZKDarkPool · ShieldedDEX · ShieldedAtomicSwap · DecentralizedCLOB

**7 attack/economic/proof specs:** SandwichAttack · FrontRunning · LatencyArbitrage · WashTrading · ImpermanentLoss · CrossVenueArbitrage · ZKRefinement

All results are TLC-verified — not just argued. See the [Conclusions](conclusions.md) chapter for the full summary of findings.

For an accessible introduction to why this matters, read the [blog post](https://github.com/oxarbitrage/formal-market-mechanisms/blob/main/blog.md).
